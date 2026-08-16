//
//  Zephyr.swift
//  Zephyr
//
//  Created by Arthur Ariel Sabintsev on 11/2/15.
//  Copyright © 2015 Arthur Ariel Sabintsev. All rights reserved.
//

import Foundation
#if os(iOS) || os(tvOS)
import UIKit
#elseif os(watchOS)
import WatchKit
#endif

@objcMembers
public final class Zephyr: NSObject, @unchecked Sendable {
    /// If **true**, console log statements are printed. Default **false**.
    public static var debugEnabled: Bool {
        get { flagLock.lock(); defer { flagLock.unlock() }; return _debugEnabled }
        set { flagLock.lock(); defer { flagLock.unlock() }; _debugEnabled = newValue }
    }

    /// If **true**, `NSUbiquitousKeyValueStore.synchronize()` is called after a batch of remote writes. Default **true**.
    public static var syncUbiquitousKeyValueStoreOnChange: Bool {
        get { flagLock.lock(); defer { flagLock.unlock() }; return _syncOnChange }
        set { flagLock.lock(); defer { flagLock.unlock() }; _syncOnChange = newValue }
    }

    /// Posted on the **main queue** after Zephyr applies one or more values from iCloud.
    ///
    /// `userInfo[Zephyr.changedKeysUserInfoKey]` is an array of `String` keys that changed.
    public static let keysDidChangeOnCloudNotification = Notification.Name("ZephyrKeysDidChangeOnCloudNotification")

    /// `userInfo` key for `keysDidChangeOnCloudNotification`. Value is `[String]`.
    public static let changedKeysUserInfoKey = "ZephyrChangedKeys"

    private static let flagLock = NSLock()
    private static var _debugEnabled = false
    private static var _syncOnChange = true

    private static let shared = Zephyr()

    private static let queueKey = DispatchSpecificKey<UInt8>()
    private let zephyrQueue: DispatchQueue = {
        let queue = DispatchQueue(label: "com.zephyr.queue")
        queue.setSpecific(key: queueKey, value: 1)
        return queue
    }()

    private var userDefaults: UserDefaults = .standard
    private var explicitSuiteName: String?
    private var monitoredKeys = Set<String>()
    private var monitoredSnapshot: [String: AnyHashable?] = [:]
    private var isApplyingRemote = false
    private var pendingRescan = false
    private var pendingCloudKeys: Set<String>?
    private var observingDefaults = false

    override init() {
        super.init()
        setupNotifications()
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    @discardableResult
    private func onQueue<T>(_ body: () -> T) -> T {
        if DispatchQueue.getSpecific(key: Self.queueKey) != nil {
            return body()
        }
        return zephyrQueue.sync(execute: body)
    }

    // MARK: - Public API

    /// Reconcile the app's persistent `UserDefaults` domain with iCloud key-value storage.
    ///
    /// Per-key logical generations decide direction. Equal generations are a no-op.
    /// Absence is never treated as deletion. System / registration-domain keys are not synced.
    ///
    /// This method returns only after local writes from a pull have been applied.
    public static func sync(keys: String...) {
        if keys.isEmpty {
            shared.reconcile(limitedTo: nil)
        } else {
            shared.reconcile(limitedTo: Set(keys))
        }
    }

    /// Reconcile an explicit list of keys. An empty array reconciles the whole app domain.
    public static func sync(keys: [String]) {
        if keys.isEmpty {
            shared.reconcile(limitedTo: nil)
        } else {
            shared.reconcile(limitedTo: Set(keys))
        }
    }

    /// Set the `UserDefaults` suite, then reconcile.
    ///
    /// For app-group suites, pass `suiteName` so Zephyr can read the persistent domain
    /// (a `UserDefaults` object does not expose its suite name).
    public static func sync(keys: String..., userDefaults: UserDefaults, suiteName: String? = nil) {
        setUserDefaultsSuite(to: userDefaults, suiteName: suiteName)
        if keys.isEmpty {
            sync()
        } else {
            sync(keys: keys)
        }
    }

    /// Set the `UserDefaults` suite, then reconcile.
    public static func sync(keys: [String], userDefaults: UserDefaults, suiteName: String? = nil) {
        setUserDefaultsSuite(to: userDefaults, suiteName: suiteName)
        if keys.isEmpty {
            sync()
        } else {
            sync(keys: keys)
        }
    }

    /// Monitor keys for local changes and push them to iCloud.
    ///
    /// Uses `UserDefaults.didChangeNotification`, so dotted keys (e.g. `com.example.theme`) work.
    public static func addKeysToBeMonitored(keys: [String]) {
        shared.onQueue {
            let added = keys.filter { !ZephyrReconciler.isMetadataKey($0) }
            shared.monitoredKeys.formUnion(added)
            shared.refreshMonitoredSnapshot()
            shared.ensureDefaultsObserver()
            for key in added {
                printObservationStatus(key: key, subscribed: true)
            }
        }
    }

    public static func addKeysToBeMonitored(keys: String...) {
        addKeysToBeMonitored(keys: keys)
    }

    public static func removeKeysFromBeingMonitored(keys: [String]) {
        shared.onQueue {
            for key in keys {
                if shared.monitoredKeys.remove(key) != nil {
                    shared.monitoredSnapshot.removeValue(forKey: key)
                    printObservationStatus(key: key, subscribed: false)
                }
            }
        }
    }

    public static func removeKeysFromBeingMonitored(keys: String...) {
        removeKeysFromBeingMonitored(keys: keys)
    }

    /// Use a different `UserDefaults` suite than `.standard`.
    ///
    /// Pass `suiteName` for app groups so full `sync()` can see the persistent domain.
    public static func setUserDefaultsSuite(to suite: UserDefaults, suiteName: String? = nil) {
        let didUpdate = shared.onQueue {
            shared.updateUserDefaultsSuite(to: suite, suiteName: suiteName)
        }
        if didUpdate {
            printStatus(status: "Updated UserDefaults suite.")
        }
    }
}

// MARK: - Setup

private extension Zephyr {
    func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keysDidChangeOnCloud(notification:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default
        )

        #if os(iOS) || os(tvOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(willEnterForeground(notification:)),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        #endif

        #if os(watchOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(willEnterForeground(notification:)),
            name: WKExtension.applicationWillEnterForegroundNotification,
            object: nil
        )
        #endif
    }

    func updateUserDefaultsSuite(to suite: UserDefaults, suiteName: String?) -> Bool {
        if userDefaults === suite, explicitSuiteName == suiteName {
            return false
        }
        if observingDefaults {
            NotificationCenter.default.removeObserver(
                self,
                name: UserDefaults.didChangeNotification,
                object: userDefaults
            )
            observingDefaults = false
        }
        userDefaults = suite
        explicitSuiteName = suiteName
        refreshMonitoredSnapshot()
        ensureDefaultsObserver()
        return true
    }

    func ensureDefaultsObserver() {
        guard !observingDefaults else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange(notification:)),
            name: UserDefaults.didChangeNotification,
            object: userDefaults
        )
        observingDefaults = true
    }

    func persistentDomainName() -> String? {
        if let explicitSuiteName { return explicitSuiteName }
        if userDefaults === UserDefaults.standard {
            return Bundle.main.bundleIdentifier
        }
        return nil
    }

    func localUserValues() -> [String: Any] {
        var values: [String: Any] = [:]
        if let name = persistentDomainName(),
           let domain = userDefaults.persistentDomain(forName: name) {
            for (key, value) in domain where !ZephyrReconciler.isMetadataKey(key) {
                values[key] = value
            }
        } else {
            for key in knownUserKeys() {
                if let value = userDefaults.object(forKey: key), !ZephyrReconciler.isMetadataKey(key) {
                    values[key] = value
                }
            }
        }
        return values
    }

    func knownUserKeys() -> Set<String> {
        var keys = monitoredKeys
        keys.formUnion(readUInt64Map(from: userDefaults, key: ZephyrReconciler.versionsKey).keys)
        keys.formUnion(readUInt64Map(from: userDefaults, key: ZephyrReconciler.tombstonesKey).keys)
        keys.formUnion(readStringArray(from: userDefaults, key: ZephyrReconciler.knownKeysKey))
        keys.formUnion(readUInt64Map(fromCloud: ZephyrReconciler.versionsKey).keys)
        keys.formUnion(readUInt64Map(fromCloud: ZephyrReconciler.tombstonesKey).keys)
        return keys.subtracting(ZephyrReconciler.metadataKeys)
    }
}

// MARK: - Reconcile

private extension Zephyr {
    func reconcile(limitedTo keys: Set<String>?) {
        printStatus(status: "Started synchronization.")
        let pulled = onQueue {
            drainReconcile(limitedTo: keys, mismatch: .preferLocal)
        }
        if !pulled.isEmpty {
            postCloudNotification(changedKeys: pulled)
        }
        printStatus(status: "Finished synchronization.")
    }

    func drainReconcile(limitedTo keys: Set<String>?, mismatch: ZephyrValueMismatchPolicy) -> [String] {
        var pulled = applyReconcile(limitedTo: keys, mismatch: mismatch)
        while let pending = pendingCloudKeys, !pending.isEmpty {
            pendingCloudKeys = nil
            pulled.append(contentsOf: applyReconcile(limitedTo: pending, mismatch: .preferRemote))
        }
        return pulled
    }

    func applyReconcile(limitedTo keys: Set<String>?, mismatch: ZephyrValueMismatchPolicy = .preferLocal) -> [String] {
        let liveMonitored = currentMonitoredValues()
        var userEdited = Set<String>()
        for key in monitoredKeys {
            if (liveMonitored[key] ?? nil) != (monitoredSnapshot[key] ?? nil) {
                userEdited.insert(key)
            }
        }
        for key in userEdited {
            recordLocalChange(key: key, deleted: liveMonitored[key] ?? nil == nil)
        }

        var local = loadLocalSnapshot()
        let remote = loadRemoteSnapshot()
        let universe = ZephyrReconciler.universe(local: local, remote: remote, limitedTo: keys)
        let bump = ZephyrReconciler.nextGeneration(local: local, remote: remote)

        var pulledKeys: [String] = []
        var didWriteRemote = false

        isApplyingRemote = true
        defer {
            refreshMonitoredSnapshot()
            isApplyingRemote = false
            if pendingRescan {
                pendingRescan = false
                pushMonitoredChanges()
            }
        }

        for key in universe.sorted() {
            let equalGen = local.generation(for: key) == remote.generation(for: key)
            switch ZephyrReconciler.decide(key: key, local: local, remote: remote, mismatch: mismatch) {
            case .pushValue:
                if let value = local.values[key] {
                    NSUbiquitousKeyValueStore.default.set(unwrap(value), forKey: key)
                    printKeySyncStatus(key: key, value: unwrap(value), destination: .remote)
                    didWriteRemote = true
                    if equalGen {
                        local.versions[key] = bump
                        local.tombstones.removeValue(forKey: key)
                    }
                }
            case .pullValue:
                if userEdited.contains(key) {
                    break
                }
                if let value = remote.values[key] {
                    userDefaults.set(unwrap(value), forKey: key)
                    local.values[key] = value
                    printKeySyncStatus(key: key, value: unwrap(value), destination: .local)
                    pulledKeys.append(key)
                    if equalGen {
                        local.versions[key] = bump
                        local.tombstones.removeValue(forKey: key)
                    }
                }
            case .pushDelete:
                NSUbiquitousKeyValueStore.default.removeObject(forKey: key)
                local.values.removeValue(forKey: key)
                printKeySyncStatus(key: key, value: nil, destination: .remote)
                didWriteRemote = true
            case .pullDelete:
                userDefaults.removeObject(forKey: key)
                local.values.removeValue(forKey: key)
                printKeySyncStatus(key: key, value: nil, destination: .local)
                pulledKeys.append(key)
            case .skip:
                break
            }
        }

        let merged = ZephyrReconciler.mergedMetadata(local: local, remote: remote, keys: universe)
        writeMetadata(versions: merged.versions, tombstones: merged.tombstones, known: universe)
        didWriteRemote = true

        if didWriteRemote && Zephyr.syncUbiquitousKeyValueStoreOnChange {
            NSUbiquitousKeyValueStore.default.synchronize()
        }

        return pulledKeys
    }

    func loadLocalSnapshot() -> ZephyrSnapshot {
        ZephyrSnapshot(
            values: hashableValues(localUserValues()),
            versions: readUInt64Map(from: userDefaults, key: ZephyrReconciler.versionsKey),
            tombstones: readUInt64Map(from: userDefaults, key: ZephyrReconciler.tombstonesKey)
        )
    }

    func loadRemoteSnapshot() -> ZephyrSnapshot {
        var values: [String: Any] = [:]
        for (key, value) in NSUbiquitousKeyValueStore.default.dictionaryRepresentation
        where !ZephyrReconciler.isMetadataKey(key) {
            values[key] = value
        }
        return ZephyrSnapshot(
            values: hashableValues(values),
            versions: readUInt64Map(fromCloud: ZephyrReconciler.versionsKey),
            tombstones: readUInt64Map(fromCloud: ZephyrReconciler.tombstonesKey)
        )
    }

    func writeMetadata(versions: [String: UInt64], tombstones: [String: UInt64], known: Set<String>) {
        let sides = ZephyrReconciler.persistBothSides(
            localVersions: readUInt64Map(from: userDefaults, key: ZephyrReconciler.versionsKey),
            localTombstones: readUInt64Map(from: userDefaults, key: ZephyrReconciler.tombstonesKey),
            localKnown: readStringArray(from: userDefaults, key: ZephyrReconciler.knownKeysKey),
            remoteVersions: readUInt64Map(fromCloud: ZephyrReconciler.versionsKey),
            remoteTombstones: readUInt64Map(fromCloud: ZephyrReconciler.tombstonesKey),
            remoteKnown: Set(NSUbiquitousKeyValueStore.default.array(forKey: ZephyrReconciler.knownKeysKey) as? [String] ?? []),
            updateVersions: versions,
            updateTombstones: tombstones,
            updateKnown: known
        )
        storeMetadata(sides.local, to: .local)
        storeMetadata(sides.remote, to: .remote)
    }

    /// Account switch: the new remote maps replace local. Do not merge the previous account.
    func replaceMetadata(versions: [String: UInt64], tombstones: [String: UInt64], known: Set<String>) {
        let payload = (
            versions: versions,
            tombstones: tombstones,
            known: known.subtracting(ZephyrReconciler.metadataKeys)
        )
        storeMetadata(payload, to: .local)
        storeMetadata(payload, to: .remote)
    }

    func storeMetadata(
        _ payload: (versions: [String: UInt64], tombstones: [String: UInt64], known: Set<String>),
        to side: Direction
    ) {
        let versionPlist = nsNumberMap(payload.versions)
        let tombPlist = nsNumberMap(payload.tombstones)
        let knownArray = Array(payload.known).sorted()
        switch side {
        case .local:
            userDefaults.set(versionPlist, forKey: ZephyrReconciler.versionsKey)
            userDefaults.set(tombPlist, forKey: ZephyrReconciler.tombstonesKey)
            userDefaults.set(knownArray, forKey: ZephyrReconciler.knownKeysKey)
            userDefaults.removeObject(forKey: ZephyrReconciler.legacySyncKey)
        case .remote:
            NSUbiquitousKeyValueStore.default.set(versionPlist, forKey: ZephyrReconciler.versionsKey)
            NSUbiquitousKeyValueStore.default.set(tombPlist, forKey: ZephyrReconciler.tombstonesKey)
            NSUbiquitousKeyValueStore.default.set(knownArray, forKey: ZephyrReconciler.knownKeysKey)
            NSUbiquitousKeyValueStore.default.removeObject(forKey: ZephyrReconciler.legacySyncKey)
        }
    }

    func recordLocalChange(key: String, deleted: Bool) {
        var local = loadLocalSnapshot()
        let remote = loadRemoteSnapshot()
        let next = ZephyrReconciler.nextGeneration(local: local, remote: remote)
        if deleted {
            local.tombstones[key] = next
            local.versions.removeValue(forKey: key)
            local.values.removeValue(forKey: key)
        } else if let value = userDefaults.object(forKey: key), let hashed = hashable(value) {
            local.versions[key] = next
            local.tombstones.removeValue(forKey: key)
            local.values[key] = hashed
        } else {
            return
        }
        let universe = ZephyrReconciler.universe(local: local, remote: remote, limitedTo: [key])
            .union([key])
        _ = applyLocalSide(local: local, remote: remote, keys: universe)
    }

    func applyLocalSide(local: ZephyrSnapshot, remote: ZephyrSnapshot, keys: Set<String>) -> [String] {
        var pulled: [String] = []
        var working = local
        isApplyingRemote = true
        defer {
            refreshMonitoredSnapshot()
            isApplyingRemote = false
        }

        for key in keys.sorted() {
            switch ZephyrReconciler.decide(key: key, local: working, remote: remote, mismatch: .preferLocal) {
            case .pushValue:
                if let value = working.values[key] {
                    NSUbiquitousKeyValueStore.default.set(unwrap(value), forKey: key)
                    printKeySyncStatus(key: key, value: unwrap(value), destination: .remote)
                }
            case .pushDelete:
                NSUbiquitousKeyValueStore.default.removeObject(forKey: key)
                printKeySyncStatus(key: key, value: nil, destination: .remote)
            case .pullValue:
                if let value = remote.values[key] {
                    userDefaults.set(unwrap(value), forKey: key)
                    working.values[key] = value
                    printKeySyncStatus(key: key, value: unwrap(value), destination: .local)
                    pulled.append(key)
                }
            case .pullDelete:
                userDefaults.removeObject(forKey: key)
                working.values.removeValue(forKey: key)
                printKeySyncStatus(key: key, value: nil, destination: .local)
                pulled.append(key)
            case .skip:
                break
            }
        }

        let merged = ZephyrReconciler.mergedMetadata(local: working, remote: remote, keys: keys)
        writeMetadata(versions: merged.versions, tombstones: merged.tombstones, known: keys)

        if Zephyr.syncUbiquitousKeyValueStoreOnChange {
            NSUbiquitousKeyValueStore.default.synchronize()
        }
        return pulled
    }

    func pushMonitoredChanges() {
        let current = currentMonitoredValues()
        let diff = ZephyrReconciler.changedMonitoredKeys(
            previous: monitoredSnapshot,
            current: current,
            monitored: monitoredKeys
        )
        for key in diff.updated {
            recordLocalChange(key: key, deleted: false)
        }
        for key in diff.deleted {
            recordLocalChange(key: key, deleted: true)
        }
        refreshMonitoredSnapshot()
    }

    func currentMonitoredValues() -> [String: AnyHashable?] {
        var values: [String: AnyHashable?] = [:]
        for key in monitoredKeys {
            values[key] = hashable(userDefaults.object(forKey: key))
        }
        return values
    }

    func refreshMonitoredSnapshot() {
        monitoredSnapshot = currentMonitoredValues()
    }
}

// MARK: - Notifications

@objc
extension Zephyr {
    func willEnterForeground(notification: Notification) {
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    func userDefaultsDidChange(notification: Notification) {
        zephyrQueue.async { [weak self] in
            guard let self else { return }
            if self.isApplyingRemote {
                self.pendingRescan = true
                return
            }
            self.pushMonitoredChanges()
        }
    }

    func keysDidChangeOnCloud(notification: Notification) {
        guard notification.name == NSUbiquitousKeyValueStore.didChangeExternallyNotification else { return }
        let userInfo = (notification as NSNotification).userInfo ?? [:]
        let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
        let cloudKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []

        switch reason {
        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            Zephyr.printStatus(status: "iCloud key-value store quota exceeded. Sync paused until the store shrinks.")
            return
        case NSUbiquitousKeyValueStoreAccountChange:
            Zephyr.printStatus(status: "iCloud account changed. Pulling remote values; not pushing the previous account's data.")
            let pulled = onQueue {
                self.applyAccountChange(cloudKeys: cloudKeys)
            }
            if !pulled.isEmpty {
                postCloudNotification(changedKeys: pulled)
            }
            return
        case NSUbiquitousKeyValueStoreInitialSyncChange, NSUbiquitousKeyValueStoreServerChange:
            break
        default:
            // Missing reason: still merge if we have keys; never require a legacy stamp.
            break
        }

        let pulled = onQueue {
            let limited = ZephyrReconciler.inboundLimit(
                cloudKeys: Set(cloudKeys),
                monitoredKeys: self.monitoredKeys
            )
            if limited.isEmpty {
                return [] as [String]
            }
            if self.isApplyingRemote {
                self.pendingCloudKeys = (self.pendingCloudKeys ?? []).union(limited)
                return [] as [String]
            }
            return self.drainReconcile(limitedTo: limited, mismatch: .preferRemote)
        }
        if !pulled.isEmpty {
            postCloudNotification(changedKeys: pulled)
        }
    }
}

private extension Zephyr {
    /// New iCloud account: remote is authoritative. Do not push the previous user's local values.
    func applyAccountChange(cloudKeys _: [String]) -> [String] {
        isApplyingRemote = true
        defer {
            refreshMonitoredSnapshot()
            isApplyingRemote = false
        }

        var pulled: [String] = []
        let remote = loadRemoteSnapshot()
        // Full remote snapshot, not the notification's changed-keys list.
        // Identical-across-accounts keys are absent from cloudKeys and must not be deleted.
        let universe = Set(remote.values.keys)
            .union(remote.versions.keys)
            .union(remote.tombstones.keys)
            .subtracting(ZephyrReconciler.metadataKeys)

        for key in universe.sorted() {
            if remote.isDeleted(key) {
                userDefaults.removeObject(forKey: key)
                pulled.append(key)
                printKeySyncStatus(key: key, value: nil, destination: .local)
            } else if let value = remote.values[key] {
                userDefaults.set(unwrap(value), forKey: key)
                pulled.append(key)
                printKeySyncStatus(key: key, value: unwrap(value), destination: .local)
            }
        }

        replaceMetadata(versions: remote.versions, tombstones: remote.tombstones, known: universe)

        // Previous iCloud account's leftover keys must not upload onto this one.
        for key in localUserValues().keys where !universe.contains(key) && !ZephyrReconciler.isMetadataKey(key) {
            userDefaults.removeObject(forKey: key)
            pulled.append(key)
        }

        return pulled
    }

    func postCloudNotification(changedKeys: [String]) {
        let keys = changedKeys
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Zephyr.keysDidChangeOnCloudNotification,
                object: nil,
                userInfo: [Zephyr.changedKeysUserInfoKey: keys]
            )
        }
    }
}

// MARK: - Plist helpers

private extension Zephyr {
    enum Direction {
        case local
        case remote
    }

    func readUInt64Map(from defaults: UserDefaults, key: String) -> [String: UInt64] {
        decodeUInt64Map(defaults.dictionary(forKey: key))
    }

    func readUInt64Map(fromCloud key: String) -> [String: UInt64] {
        decodeUInt64Map(NSUbiquitousKeyValueStore.default.dictionary(forKey: key))
    }

    func readStringArray(from defaults: UserDefaults, key: String) -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    func decodeUInt64Map(_ raw: [String: Any]?) -> [String: UInt64] {
        guard let raw else { return [:] }
        var out: [String: UInt64] = [:]
        for (key, value) in raw {
            if let number = value as? NSNumber {
                out[key] = number.uint64Value
            } else if let int = value as? UInt64 {
                out[key] = int
            } else if let int = value as? Int, int >= 0 {
                out[key] = UInt64(int)
            }
        }
        return out
    }

    func nsNumberMap(_ map: [String: UInt64]) -> [String: NSNumber] {
        var out: [String: NSNumber] = [:]
        for (key, value) in map {
            out[key] = NSNumber(value: value)
        }
        return out
    }

    func hashableValues(_ values: [String: Any]) -> [String: AnyHashable] {
        var out: [String: AnyHashable] = [:]
        for (key, value) in values {
            if let hashed = hashable(value) {
                out[key] = hashed
            }
        }
        return out
    }

    func hashable(_ value: Any?) -> AnyHashable? {
        guard let value else { return nil }
        if let hashed = value as? AnyHashable { return hashed }
        if let array = value as? [Any] { return array as NSArray }
        if let dict = value as? [String: Any] { return dict as NSDictionary }
        return value as? NSObject
    }

    func unwrap(_ value: AnyHashable) -> Any {
        value.base
    }
}

// MARK: - Logging

private extension Zephyr {
    static func printKeySyncStatus(key: String, value: Any?, destination: Direction) {
        shared.printKeySyncStatus(key: key, value: value, destination: destination)
    }

    static func printObservationStatus(key: String, subscribed: Bool) {
        guard debugEnabled else { return }
        let state = subscribed ? "Subscribed" : "Unsubscribed"
        let preposition = subscribed ? "for" : "from"
        printStatus(status: "\(state) '\(key)' \(preposition) observation.")
    }

    static func printStatus(status: String) {
        guard debugEnabled else { return }
        print("[Zephyr] \(status)")
    }

    func printKeySyncStatus(key: String, value: Any?, destination: Direction) {
        guard Zephyr.debugEnabled else { return }
        let destinationText = destination == .local ? "FROM iCloud" : "TO iCloud."
        if let value {
            Zephyr.printStatus(status: "Synchronized key '\(key)' with value '\(value)' \(destinationText)")
        } else {
            Zephyr.printStatus(status: "Synchronized key '\(key)' with value 'nil' \(destinationText)")
        }
    }

    func printObservationStatus(key: String, subscribed: Bool) {
        Zephyr.printObservationStatus(key: key, subscribed: subscribed)
    }

    func printStatus(status: String) {
        Zephyr.printStatus(status: status)
    }
}
