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
    static var debugEnabled = false

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
        addObservers()
    }

    /**

     Zephyr's main method.
     
     Zephyr will synchronize all NSUserDefaults with NSUbiquitousKeyValueStore, depdending on what data is newer.
     
     If a key is passed, only that key will be synchronized.

     - parameter key: If you pass a key, only that key will be synchronized. If no key is passed, than all NSUserDefaults will be synchronized with NSUbiquitousKeyValueStore.

     */
    static func sync(key: String? = nil) {

        defer {
            sharedInstance.addObservers()
        }

        sharedInstance.removeObservers()

        switch sharedInstance.newestDataByComparingLastSyncDates() {
            
        case .Local:

            guard let key = key else {
                sharedInstance.syncToCloud()
                return
            }

            let value = sharedInstance.ZephyrLocalStoreDictionary[key]
            sharedInstance.syncToCloud(key: key, value: value)

        case .Remote:

            guard let key = key else {
                sharedInstance.syncFromCloud()
                return
            }

            let value = sharedInstance.ZephyrRemoteStoreDictionary[key]
            sharedInstance.syncFromCloud(key: key, value: value)
        }

    }

    static func addKeysToBeMonitored(keys: String...) {

        for key in keys {

            if sharedInstance.monitoredKeys.contains(key) == false {
                sharedInstance.monitoredKeys.append(key)
                sharedInstance.addObservers(key)
            }

        }
    }

    static func removeKeysFromBeingMonitored(keys: String...) {

        for (index, key) in keys.enumerate() {

            if sharedInstance.monitoredKeys.contains(key) == false {
                sharedInstance.monitoredKeys.removeAtIndex(index)
                sharedInstance.removeObservers(key)
            }
            
        }
    }

}

// MARK: Sync
private extension Zephyr {

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
                Zephyr.printStatus("Syncing Key '\(key)' with value '\(value)' TO iCloud.")
                ubiquitousStore.setObject(value, forKey: key)
            }

            ubiquitousStore.synchronize()

            return
        }

        if let value = value {
            Zephyr.printStatus("Synchronizing Key '\(key)' with value '\(value)' TO iCloud.")
            ubiquitousStore.setObject(value, forKey: key)
            ubiquitousStore.synchronize()
        }
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
                Zephyr.printStatus("Synchronizing Key '\(key)' with value '\(value)' FROM iCloud.")
                defaults.setObject(value, forKey: key)
            }

            defaults.synchronize()

            return
        }

        if let value = value {
            Zephyr.printStatus("Synchronizing Key '\(key)' with value '\(value)' FROM iCloud.")
            defaults.setObject(value, forKey: key)
            defaults.synchronize()
        }
    }

}


// MARK: Helpers
private extension Zephyr {

    /**

     Compares the last sync date between NSUbiquitousKeyValueStore and NSUserDefaults.
     
     If no data exists in NSUbiquitousKeyValueStore, then NSUbiquitousKeyValueStore will synchronize NSUserDefaults.
     If no data exists in NSUserDefaults, then NSUserDefaults will synchronize NSUbiquitousKeyValueStore.

     */

    func newestDataByComparingLastSyncDates() -> ZephyrDataStore {

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
                Zephyr.printStatus("Subscribed \(key) for observation.")
                NSUserDefaults.standardUserDefaults().addObserver(self, forKeyPath: key, options: .New, context: nil)
                NSUbiquitousKeyValueStore.defaultStore().addObserver(self, forKeyPath: key, options: .New, context: nil)
            }

            return
        }

        Zephyr.printStatus("Subscribed \(key) for observation.")
        NSUserDefaults.standardUserDefaults().addObserver(self, forKeyPath: key, options: .New, context: nil)
        NSUbiquitousKeyValueStore.defaultStore().addObserver(self, forKeyPath: key, options: .New, context: nil)

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
                Zephyr.printStatus("Unsubscribed \(key) from observation.")
            }

            return
        }

        NSUserDefaults.standardUserDefaults().removeObserver(self, forKeyPath: key, context: nil)
        NSUbiquitousKeyValueStore.defaultStore().removeObserver(self, forKeyPath: key, context: nil)
        Zephyr.printStatus("Unsubscribed \(key) from observation.")
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

// MARK: Logging
private extension Zephyr {

    /**

     Prints a status to the console if ```debugEnabled == true```

     - parameter status: The string that should be printed to the console.

     */
    static func printStatus(status: String) {
        if debugEnabled == true {
            print("[Zephyr] \(status)")
        }
    }

}
