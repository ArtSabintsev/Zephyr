//
//  Zephyr.swift
//  Zephyr
//
//  Created by Arthur Ariel Sabintsev on 11/2/15.
//  Copyright © 2015 Arthur Ariel Sabintsev. All rights reserved.
//

import Foundation

/**

 Enumerates the Local (NSUserDefaults) and Remote (NSUNSUbiquitousKeyValueStore) data stores

 */
private enum ZephyrDataStore {
    case Local  // NSUserDefaults
    case Remote // NSUbiquitousKeyValueStore
}

public class Zephyr: NSObject {

    /**

     A debug flag.

     If **true**, then this will enable console  log statements.

     By default, this flag is set to **false**.

     */
    public static var debugEnabled = false

    /**

     The singleton for Zephyr.

     */
    private static let sharedInstance = Zephyr()

    /**

     A shared key that stores the last synchronization date between NSUserDefaults and NSUbiquitousKeyValueStore

     */
    private let ZephyrSyncKey = "ZephyrSyncKey"

    private var monitoredKeys = [String]()

    /**

     A session-persisted variable to directly access all of the NSUserDefaults elements

     */
    private var ZephyrLocalStoreDictionary: [String: AnyObject] {
        get {
            return NSUserDefaults.standardUserDefaults().dictionaryRepresentation()
        }
    }

    /**

     A session-persisted variable to directly access all of the NSUbiquitousKeyValueStore elements

     */
    private var ZephyrRemoteStoreDictionary: [String: AnyObject]  {
        get {
            return NSUbiquitousKeyValueStore.defaultStore().dictionaryRepresentation
        }
    }

    /**

     Zephyr's initialization method.

     Do not call this method directly. Instead, call Zephyr.sync() to initialize synchronization.

     */
    override init() {
        super.init()
        Zephyr.printStatus("Initialized.")
        addObservers()
    }

    /**

     Zephyr's main synchronization method.

     Zephyr will synchronize all NSUserDefaults with NSUbiquitousKeyValueStore, depdending on what data is newer.

     If one or more keys are passed, only those keys will be synchronized.

     - parameter keys: If you pass a one or more keys, only those key will be synchronized. If no keys are passed, than all NSUserDefaults will be synchronized with NSUbiquitousKeyValueStore.

     */
    public static func sync(keys: String...) {

        defer {
            sharedInstance.addObservers()
        }

        sharedInstance.removeObservers()

        switch sharedInstance.dataStoreWithLatestData() {

        case .Local:

            Zephyr.printStatus("Beginning synchronization TO iCloud.")

            if keys.count > 0 {
                sharedInstance.syncSpecificKeys(keys, dataStore: .Local)
            } else {
                sharedInstance.syncToCloud()
            }

            Zephyr.printStatus("Finished synchronization TO iCloud.")

        case .Remote:

            Zephyr.printStatus("Beginning synchronization FROM iCloud.")

            if keys.count > 0 {
                sharedInstance.syncSpecificKeys(keys, dataStore: .Remote)
            } else {
                sharedInstance.syncFromCloud()
            }

            Zephyr.printStatus("Finished synchronization FROM iCloud.")

        }

    }


    /**

     Add specific keys to be monitored in the background. Monitored keys will automatically
     be synchronized between both data stores whenever a change is detected

     - parameter keys: Pass one or more keys that you would like to begin monitoring.

     */
    public static func addKeysToBeMonitored(keys: String...) {

        for key in keys {

            if sharedInstance.monitoredKeys.contains(key) == false {
                sharedInstance.monitoredKeys.append(key)
                sharedInstance.addObservers(key)
            }

        }
    }

    /**

     Remove specific keys from being monitored in the background.

     - parameter keys: Pass one or more keys that you would like to stop monitoring.

     */
    public static func removeKeysFromBeingMonitored(keys: String...) {

        for (index, key) in keys.enumerate() {

            if sharedInstance.monitoredKeys.contains(key) == false {
                sharedInstance.monitoredKeys.removeAtIndex(index)
                sharedInstance.removeObservers(key)
            }

        }
    }

}

// MARK: Synchronizers

private extension Zephyr {

    /**

     Synchronizes specific keys to/from NSUbiquitousKeyValueStore and NSUserDefaults.

     - parameter keys: Array of leys to synchronize.
     - parameter dataStore: Signifies if keys should be synchronized to/from iCloud.

     */
    func syncSpecificKeys(keys: [String], dataStore: ZephyrDataStore) {

        for key in keys {
            switch dataStore {
            case .Local:
                let value = ZephyrLocalStoreDictionary[key]
                syncToCloud(key: key, value: value)
            case .Remote:
                let value = ZephyrRemoteStoreDictionary[key]
                syncFromCloud(key: key, value: value)
            }
        }

    }

    /**

     Synchronizes all NSUserDefaults to NSUbiquitousKeyValueStore.

     If a key is passed, only that key will be synchronized.

     - parameter key: If you pass a key, only that key will updated in NSUbiquitousKeyValueStore.
     - parameter value: The value that will be synchronized. Must be passed with a key, otherwise, nothing will happen.

     */
    func syncToCloud(key key: String? = nil, value: AnyObject? = nil) {

        let ubiquitousStore = NSUbiquitousKeyValueStore.defaultStore()
        ubiquitousStore.setObject(NSDate(), forKey: ZephyrSyncKey)

        // Sync all defaults to iCloud if key is nil, otherwise sync only the specific key/value pair.
        guard let key = key else {
            for (key, value) in ZephyrLocalStoreDictionary {
                ubiquitousStore.setObject(value, forKey: key)
                Zephyr.printSyncStatus(key, value: value, destination: .Remote)
            }

            ubiquitousStore.synchronize()

            return
        }

        if let value = value {
            ubiquitousStore.setObject(value, forKey: key)
            Zephyr.printSyncStatus(key, value: value, destination: .Remote)
        } else {
            ubiquitousStore.setObject(nil, forKey: key)
            Zephyr.printSyncStatus(key, value: value, destination: .Remote)
        }

        ubiquitousStore.synchronize()

    }

    /**

     Synchronizes all NSUbiquitousKeyValueStore to NSUserDefaults.

     If a key is passed, only that key will be synchronized.

     - parameter key: If you pass a key, only that key will updated in NSUserDefaults.
     - parameter value: The value that will be synchronized. Must be passed with a key, otherwise, nothing will happen.

     */
    func syncFromCloud(key key: String? = nil, value: AnyObject? = nil) {

        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setObject(NSDate(), forKey: ZephyrSyncKey)

        // Sync all defaults from iCloud if key is nil, otherwise sync only the specific key/value pair.
        guard let key = key else {
            for (key, value) in ZephyrRemoteStoreDictionary {
                defaults.setObject(value, forKey: key)
                Zephyr.printSyncStatus(key, value: value, destination: .Local)
            }

            defaults.synchronize()

            return
        }

        if let value = value {
            defaults.setObject(value, forKey: key)
            Zephyr.printSyncStatus(key, value: value, destination: .Local)
        } else {
            defaults.setObject(nil, forKey: key)
            Zephyr.printSyncStatus(key, value: nil, destination: .Local)
        }

        defaults.synchronize()
    }

}

// MARK: Observers
extension Zephyr {

    /**

     Adds NSUserDefaultsDidChangeNotification and NSUbiquitousKeyValueStoreDidChangeExternallyNotification to NSNotificationCenter after synchronization.

     - parameter dataStore: The data store

     */
    private func addObservers(key: String? = nil) {

        guard let key = key else {

            for key in monitoredKeys {

                if key == ZephyrSyncKey {
                    return

                }

                NSUserDefaults.standardUserDefaults().addObserver(self, forKeyPath: key, options: .New, context: nil)
                NSUbiquitousKeyValueStore.defaultStore().addObserver(self, forKeyPath: key, options: .New, context: nil)
                Zephyr.printObservationStatus(key, subscribed: true)
            }

            return
        }

        NSUserDefaults.standardUserDefaults().addObserver(self, forKeyPath: key, options: .New, context: nil)
        NSUbiquitousKeyValueStore.defaultStore().addObserver(self, forKeyPath: key, options: .New, context: nil)
        Zephyr.printObservationStatus(key, subscribed: true)
    }

    /**

     Removes NSUserDefaultsDidChangeNotification and NSUbiquitousKeyValueStoreDidChangeExternallyNotification from NSNotificationCenter before synchronization.

     - parameter dataStore: The data store

     */
    private func removeObservers(key: String? = nil) {

        guard let key = key else {

            for key in monitoredKeys {

                if key == ZephyrSyncKey {
                    return
                }


                NSUserDefaults.standardUserDefaults().removeObserver(self, forKeyPath: key, context: nil)
                NSUbiquitousKeyValueStore.defaultStore().removeObserver(self, forKeyPath: key, context: nil)
                Zephyr.printObservationStatus(key, subscribed: false)
            }

            return
        }

        NSUserDefaults.standardUserDefaults().removeObserver(self, forKeyPath: key, context: nil)
        NSUbiquitousKeyValueStore.defaultStore().removeObserver(self, forKeyPath: key, context: nil)
        Zephyr.printObservationStatus(key, subscribed: false)
    }

    override public func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {

        guard let keyPath = keyPath, object = object else {
            return
        }

        if object is NSUserDefaults {
            NSUserDefaults.standardUserDefaults().setObject(NSDate(), forKey: ZephyrSyncKey)
        } else if object is NSUbiquitousKeyValueStore {
            NSUbiquitousKeyValueStore.defaultStore().setObject(NSDate(), forKey: ZephyrSyncKey)
        }

        Zephyr.sync(keyPath)
    }

}

// MARK: Helpers

private extension Zephyr {

    /**

     Compares the last sync date between NSUbiquitousKeyValueStore and NSUserDefaults.

     If no data exists in NSUbiquitousKeyValueStore, then NSUbiquitousKeyValueStore will synchronize NSUserDefaults.
     If no data exists in NSUserDefaults, then NSUserDefaults will synchronize NSUbiquitousKeyValueStore.

     */
    func dataStoreWithLatestData() -> ZephyrDataStore {

        if let remoteDate = ZephyrRemoteStoreDictionary[ZephyrSyncKey] as? NSDate,
            localDate = ZephyrLocalStoreDictionary[ZephyrSyncKey] as? NSDate {

                // If both localDate and remoteDate exist, compare the two, and the synchronize the data stores.
                return localDate.timeIntervalSince1970 > remoteDate.timeIntervalSince1970 ? .Local : .Remote

        } else {

            // If remoteDate doesn't exist, then assume local data is newer.
            guard let _ = ZephyrRemoteStoreDictionary[ZephyrSyncKey] as? NSDate else {
                return .Local
            }

            // If localDate doesn't exist, then assume that remote data is newer.
            guard let _ = ZephyrLocalStoreDictionary[ZephyrSyncKey] as? NSDate else {
                return .Remote
            }

            // If neither exist, synchronize local data store to iCloud.
            return .Local
        }

    }

    /**

     Prints the key, value, and destination of the synchronized information if

         debugEnabled == true

     - parameter key: The key being synchronized.
     - parameter value: The value being synchronized.
     - parameter destination: The data store that is receiving the updated key-value pair.
     
     */
    static func printSyncStatus(key: String, value: AnyObject?, destination dataStore: ZephyrDataStore) {
        let destination = dataStore == .Local ? "FROM iCloud" : "TO iCloud."

        if debugEnabled == true {

            guard let value = value else {
                print("[Zephyr] Synchronized key '\(key)' with value 'nil' \(destination)")
                return
            }

            print("[Zephyr] Synchronized key '\(key)' with value '\(value)' \(destination)")
        }
    }

    /**

     Prints the subscription state for a specific key if

         debugEnabled == true

     - parameter key: The key being synchronized.
     - parameter subscribed: The subscription status of the key.

     */
    static func printObservationStatus(key: String, subscribed: Bool) {
        let subscriptionState = subscribed == true ? "Subscribed" : "Unsubscribed"
        let preposition = subscribed == true ? "for" : "from"

        if debugEnabled == true {
            print("\(subscriptionState) '\(key)' \(preposition) observation.")
        }
    }

    /**

     Prints a status to the console if

         debugEnabled == true

     - parameter status: The string that should be printed to the console.
     
     */
    static func printStatus(status: String) {
        if debugEnabled == true {
            print("[Zephyr] \(status)")
        }
    }

}
