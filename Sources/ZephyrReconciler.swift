//
//  ZephyrReconciler.swift
//  Zephyr
//
//  Per-key merge decisions. Logical generations, not wall clocks.
//  Metadata keys are never treated as user data.
//

import Foundation

enum ZephyrMergeAction: Equatable {
    case pushValue
    case pullValue
    case pushDelete
    case pullDelete
    case skip
}

/// When both sides have the same generation but different values.
enum ZephyrValueMismatchPolicy: Equatable {
    /// Explicit `Zephyr.sync()` — this device just asked to publish its state.
    case preferLocal
    /// Inbound iCloud notification — the other device published first.
    case preferRemote
    case skip
}

struct ZephyrSnapshot: Equatable {
    var values: [String: AnyHashable]
    var versions: [String: UInt64]
    var tombstones: [String: UInt64]

    init(
        values: [String: AnyHashable] = [:],
        versions: [String: UInt64] = [:],
        tombstones: [String: UInt64] = [:]
    ) {
        self.values = values
        self.versions = versions
        self.tombstones = tombstones
    }

    func generation(for key: String) -> UInt64 {
        max(versions[key] ?? 0, tombstones[key] ?? 0)
    }

    func isDeleted(_ key: String) -> Bool {
        let tomb = tombstones[key] ?? 0
        let ver = versions[key] ?? 0
        return tomb > ver && tomb > 0
    }

    func isPresent(_ key: String) -> Bool {
        values[key] != nil && !isDeleted(key)
    }
}

enum ZephyrReconciler {
    static let versionsKey = "Zephyr.v5.versions"
    static let tombstonesKey = "Zephyr.v5.tombstones"
    static let knownKeysKey = "Zephyr.v5.knownKeys"
    static let legacySyncKey = "ZephyrSyncKey"

    static var metadataKeys: Set<String> {
        [versionsKey, tombstonesKey, knownKeysKey, legacySyncKey]
    }

    static func isMetadataKey(_ key: String) -> Bool {
        metadataKeys.contains(key)
    }

    /// Highest generation seen on either side, plus one.
    static func nextGeneration(local: ZephyrSnapshot, remote: ZephyrSnapshot) -> UInt64 {
        let all = Array(local.versions.values)
            + Array(local.tombstones.values)
            + Array(remote.versions.values)
            + Array(remote.tombstones.values)
        return (all.max() ?? 0) + 1
    }

    static func decide(
        key: String,
        local: ZephyrSnapshot,
        remote: ZephyrSnapshot,
        mismatch: ZephyrValueMismatchPolicy = .preferLocal
    ) -> ZephyrMergeAction {
        guard !isMetadataKey(key) else { return .skip }

        let localGen = local.generation(for: key)
        let remoteGen = remote.generation(for: key)
        let localPresent = local.isPresent(key)
        let remotePresent = remote.isPresent(key)

        // v4 / first-run: no generations. Never treat absence as delete.
        if localGen == 0 && remoteGen == 0 {
            if localPresent && !remotePresent { return .pushValue }
            if remotePresent && !localPresent { return .pullValue }
            if localPresent && remotePresent && local.values[key] != remote.values[key] {
                return action(forMismatch: mismatch)
            }
            return .skip
        }

        if localGen > remoteGen {
            return local.isDeleted(key) ? .pushDelete : .pushValue
        }
        if remoteGen > localGen {
            return remote.isDeleted(key) ? .pullDelete : .pullValue
        }

        // Equal generations. Absence is never a delete.
        if localPresent && !remotePresent { return .pushValue }
        if remotePresent && !localPresent { return .pullValue }
        if localPresent && remotePresent && local.values[key] != remote.values[key] {
            return action(forMismatch: mismatch)
        }
        return .skip
    }

    private static func action(forMismatch mismatch: ZephyrValueMismatchPolicy) -> ZephyrMergeAction {
        switch mismatch {
        case .preferLocal: return .pushValue
        case .preferRemote: return .pullValue
        case .skip: return .skip
        }
    }

    /// Overlay a limited pass onto the full maps. Keys not in the update are kept.
    static func persistMetadata(
        existingVersions: [String: UInt64],
        existingTombstones: [String: UInt64],
        existingKnown: Set<String>,
        updateVersions: [String: UInt64],
        updateTombstones: [String: UInt64],
        updateKnown: Set<String>
    ) -> (versions: [String: UInt64], tombstones: [String: UInt64], known: Set<String>) {
        var versions = existingVersions
        var tombstones = existingTombstones
        for (key, value) in updateVersions {
            versions[key] = value
            tombstones.removeValue(forKey: key)
        }
        for (key, value) in updateTombstones {
            tombstones[key] = value
            versions.removeValue(forKey: key)
        }
        return (versions, tombstones, existingKnown.union(updateKnown).subtracting(metadataKeys))
    }

    /// Each store keeps its own unreconciled metadata. Only `update*` keys converge.
    static func persistBothSides(
        localVersions: [String: UInt64],
        localTombstones: [String: UInt64],
        localKnown: Set<String>,
        remoteVersions: [String: UInt64],
        remoteTombstones: [String: UInt64],
        remoteKnown: Set<String>,
        updateVersions: [String: UInt64],
        updateTombstones: [String: UInt64],
        updateKnown: Set<String>
    ) -> (
        local: (versions: [String: UInt64], tombstones: [String: UInt64], known: Set<String>),
        remote: (versions: [String: UInt64], tombstones: [String: UInt64], known: Set<String>)
    ) {
        (
            persistMetadata(
                existingVersions: localVersions,
                existingTombstones: localTombstones,
                existingKnown: localKnown,
                updateVersions: updateVersions,
                updateTombstones: updateTombstones,
                updateKnown: updateKnown
            ),
            persistMetadata(
                existingVersions: remoteVersions,
                existingTombstones: remoteTombstones,
                existingKnown: remoteKnown,
                updateVersions: updateVersions,
                updateTombstones: updateTombstones,
                updateKnown: updateKnown
            )
        )
    }

    /// Keys an inbound iCloud event may touch. Empty means do nothing.
    ///
    /// No monitored keys is "not watching", not "watch the whole domain".
    /// A missing changed-keys list (initial sync) still stays inside `monitoredKeys`.
    static func inboundLimit(cloudKeys: Set<String>, monitoredKeys: Set<String>) -> Set<String> {
        if monitoredKeys.isEmpty {
            return []
        }
        let interesting = cloudKeys.subtracting(metadataKeys)
        if interesting.isEmpty {
            return monitoredKeys.subtracting(metadataKeys)
        }
        return interesting.intersection(monitoredKeys)
    }

    static func universe(local: ZephyrSnapshot, remote: ZephyrSnapshot, limitedTo keys: Set<String>?) -> Set<String> {
        let all = Set(local.values.keys)
            .union(remote.values.keys)
            .union(local.versions.keys)
            .union(remote.versions.keys)
            .union(local.tombstones.keys)
            .union(remote.tombstones.keys)
            .subtracting(metadataKeys)
        if let keys {
            return keys.subtracting(metadataKeys)
        }
        return all
    }

    /// After applying actions, both sides should share the winner's metadata.
    static func mergedMetadata(
        local: ZephyrSnapshot,
        remote: ZephyrSnapshot,
        keys: Set<String>
    ) -> (versions: [String: UInt64], tombstones: [String: UInt64]) {
        var versions: [String: UInt64] = [:]
        var tombstones: [String: UInt64] = [:]

        for key in keys {
            guard !isMetadataKey(key) else { continue }
            let localGen = local.generation(for: key)
            let remoteGen = remote.generation(for: key)
            let winner: ZephyrSnapshot
            if localGen > remoteGen {
                winner = local
            } else if remoteGen > localGen {
                winner = remote
            } else if local.isPresent(key) {
                winner = local
            } else if remote.isPresent(key) {
                winner = remote
            } else if (local.tombstones[key] ?? 0) > 0 || (remote.tombstones[key] ?? 0) > 0 {
                winner = (local.tombstones[key] ?? 0) >= (remote.tombstones[key] ?? 0) ? local : remote
            } else {
                continue
            }

            if winner.isDeleted(key), let tomb = winner.tombstones[key] {
                tombstones[key] = tomb
            } else if let ver = winner.versions[key] {
                versions[key] = ver
            } else if winner.isPresent(key) {
                versions[key] = max(localGen, remoteGen, 1)
            }
        }

        return (versions, tombstones)
    }

    static func changedMonitoredKeys(
        previous: [String: AnyHashable?],
        current: [String: AnyHashable?],
        monitored: Set<String>
    ) -> (updated: [String], deleted: [String]) {
        var updated: [String] = []
        var deleted: [String] = []
        for key in monitored {
            let before = previous[key] ?? nil
            let after = current[key] ?? nil
            if before == after { continue }
            if after == nil {
                deleted.append(key)
            } else {
                updated.append(key)
            }
        }
        return (updated, deleted)
    }
}
