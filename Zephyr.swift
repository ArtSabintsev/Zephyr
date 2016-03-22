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

     If **true**, then this will enable console log statements.

     By default, this flag is set to **false**.

     */
    public static var debugEnabled = false

    /**

     If **true**, then NSUbiquitousKeyValueStore.synchronize() will be called immediately after any change is made

     */
    public static var syncUbiquitousStoreKeyValueStoreOnChange = true

    /**

     The singleton for Zephyr.

     */
    private static let sharedInstance = Zephyr()

    /**

     A shared key that stores the last synchronization date between NSUserDefaults and NSUbiquitousKeyValueStore

     */
    private let ZephyrSyncKey = "ZephyrSyncKey"


    /**

     An array of keys that should be actively monitored for changes

     */
    private var monitoredKeys = [String]()

    /**

     An array of keys that are currently registered for observation

     */
    private var registeredObservationKeys = [String]()

    /**

     A queue used to serialize synchronization on monitored keys

     */
    private let zephyrQueue = dispatch_queue_create("com.zephyr.queue", DISPATCH_QUEUE_SERIAL);


    /**

     A session-persisted variable to directly access all of the NSUserDefaults elements

     */
    private var zephyrLocalStoreDictionary: [String: AnyObject] {
        get {
            return NSUserDefaults.standardUserDefaults().dictionaryRepresentation()
        }
    }

    /**

     A session-persisted variable to directly access all of the NSUbiquitousKeyValueStore elements

     */
    private var zephyrRemoteStoreDictionary: [String: AnyObject]  {
        get {
            return NSUbiquitousKeyValueStore.defaultStore().dictionaryRepresentation
        }
    }

    /**

     Zephyr's initialization method

     Do not call it directly.
     */
    override init() {
        super.init()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(keysDidChangeOnCloud(_:)), name: NSUbiquitousKeyValueStoreDidChangeExternallyNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(willEnterForeground(_:)), name:
            UIApplicationWillEnterForegroundNotification, object: nil)

        NSUbiquitousKeyValueStore.defaultStore().synchronize()
    }


    /**

     Zephyr's de-initialization method

     */
    deinit {
        dispatch_sync(zephyrQueue, {
            for key in self.registeredObservationKeys {
                NSUserDefaults.standardUserDefaults().removeObserver(self, forKeyPath: key)
            }
        })
    }

    /**

     Zephyr's synchronization method.

     Zephyr will synchronize all NSUserDefaults with NSUbiquitousKeyValueStore.

     If one or more keys are passed, only those keys will be synchronized.

     - parameter keys: If you pass a one or more keys, only those key will be synchronized. If no keys are passed, than all NSUserDefaults will be synchronized with NSUbiquitousKeyValueStore.

     */
    public static func sync(keys: String...) {
        if keys.count > 0 {
            sync(keys)
            return
        }

        switch sharedInstance.dataStoreWithLatestData() {

        case .Local:

            printGeneralSyncStatus(false, destination: .Remote)
            dispatch_sync(sharedInstance.zephyrQueue) {
                sharedInstance.syncToCloud()
            }
            printGeneralSyncStatus(true, destination: .Remote)

        case .Remote:

            printGeneralSyncStatus(false, destination: .Local)
            dispatch_sync(sharedInstance.zephyrQueue) {
                sharedInstance.syncFromCloud()
            }
            printGeneralSyncStatus(true, destination: .Local)

        }

    }

    /**

     Overloaded version of Zephyr's synchronization method, **sync(_:)**.

     This method will synchronize an array of keys between NSUserDefaults and NSUbiquitousKeyValueStore.

     - parameter keys: An array of keys that should be synchronized between NSUserDefaults and NSUbiquitousKeyValueStore.

     */
    public static func sync(keys: [String]) {

        switch sharedInstance.dataStoreWithLatestData() {

        case .Local:

            printGeneralSyncStatus(false, destination: .Remote)
            dispatch_sync(sharedInstance.zephyrQueue) {
                sharedInstance.syncSpecificKeys(keys, dataStore: .Local)
            }
            printGeneralSyncStatus(true, destination: .Remote)

        case .Remote:

            printGeneralSyncStatus(false, destination: .Local)
            dispatch_sync(sharedInstance.zephyrQueue) {
                sharedInstance.syncSpecificKeys(keys, dataStore: .Remote)
            }
            printGeneralSyncStatus(true, destination: .Local)

        }

    }

    /**

     Add specific keys to be monitored in the background. Monitored keys will automatically
     be synchronized between both data stores whenever a change is detected

     - parameter keys: Pass one or more keys that you would like to begin monitoring.

     */
    public static func addKeysToBeMonitored(keys: [String]) {

        for key in keys {

            if sharedInstance.monitoredKeys.contains(key) == false {
                sharedInstance.monitoredKeys.append(key)

                dispatch_sync(sharedInstance.zephyrQueue) {
                    sharedInstance.registerObserver(key)
                }
            }

        }
    }

    /**

     Overloaded version of the **addKeysToBeMonitored(_:)** method.

     Add specific keys to be monitored in the background. Monitored keys will automatically
     be synchronized between both data stores whenever a change is detected

     - parameter keys: Pass one or more keys that you would like to begin monitoring.

     */
    public static func addKeysToBeMonitored(keys: String...) {

        addKeysToBeMonitored(keys)

    }

    /**

     Remove specific keys from being monitored in the background.

     - parameter keys: Pass one or more keys that you would like to stop monitoring.

     */
    public static func removeKeysFromBeingMonitored(keys: [String]) {

        for key in keys {
            if sharedInstance.monitoredKeys.contains(key) == true {
                sharedInstance.monitoredKeys = sharedInstance.monitoredKeys.filter({$0 != key })

                dispatch_sync(sharedInstance.zephyrQueue) {
                    sharedInstance.unregisterObserver(key)
                }
            }
        }
    }

    /**

     Overloaded version of the **removeKeysFromBeingMonitored(_:)** method.

     Remove specific keys from being monitored in the background.

     - parameter keys: Pass one or more keys that you would like to stop monitoring.

     */
    public static func removeKeysFromBeingMonitored(keys: String...) {

        removeKeysFromBeingMonitored(keys)

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

        if let remoteDate = zephyrRemoteStoreDictionary[ZephyrSyncKey] as? NSDate,
            localDate = zephyrLocalStoreDictionary[ZephyrSyncKey] as? NSDate {

                // If both localDate and remoteDate exist, compare the two, and the synchronize the data stores.
                return localDate.timeIntervalSince1970 > remoteDate.timeIntervalSince1970 ? .Local : .Remote

        } else {

            // If remoteDate doesn't exist, then assume local data is newer.
            guard let _ = zephyrRemoteStoreDictionary[ZephyrSyncKey] as? NSDate else {
                return .Local
            }

            // If localDate doesn't exist, then assume that remote data is newer.
            guard let _ = zephyrLocalStoreDictionary[ZephyrSyncKey] as? NSDate else {
                return .Remote
            }

            // If neither exist, synchronize local data store to iCloud.
            return .Local
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
                let value = zephyrLocalStoreDictionary[key]
                syncToCloud(key: key, value: value)
            case .Remote:
                let value = zephyrRemoteStoreDictionary[key]
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
            for (key, value) in zephyrLocalStoreDictionary {
                unregisterObserver(key)
                ubiquitousStore.setObject(value, forKey: key)
                Zephyr.printKeySyncStatus(key, value: value, destination: .Remote)
                if Zephyr.syncUbiquitousStoreKeyValueStoreOnChange {
                    ubiquitousStore.synchronize()
                }
                registerObserver(key)
            }

            return
        }

        unregisterObserver(key)

        if let value = value {
            ubiquitousStore.setObject(value, forKey: key)
            Zephyr.printKeySyncStatus(key, value: value, destination: .Remote)
        } else {
            ubiquitousStore.setObject(nil, forKey: key)
            Zephyr.printKeySyncStatus(key, value: value, destination: .Remote)
        }

        if Zephyr.syncUbiquitousStoreKeyValueStoreOnChange {
            ubiquitousStore.synchronize()
        }

        registerObserver(key)
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
            for (key, value) in zephyrRemoteStoreDictionary {
                unregisterObserver(key)
                defaults.setObject(value, forKey: key)
                Zephyr.printKeySyncStatus(key, value: value, destination: .Local)
                registerObserver(key)
            }

            return
        }

        unregisterObserver(key)

        if let value = value {
            defaults.setObject(value, forKey: key)
            Zephyr.printKeySyncStatus(key, value: value, destination: .Local)
        } else {
            defaults.setObject(nil, forKey: key)
            Zephyr.printKeySyncStatus(key, value: nil, destination: .Local)
        }

        registerObserver(key)
    }

}

// MARK: Observers

extension Zephyr {

    /**

     Adds key-value observation after synchronization of a specific key.

     - parameter key: The key that should be added and monitored.

     */
    private func registerObserver(key: String) {

        if key == ZephyrSyncKey {
            return
        }

        if !self.registeredObservationKeys.contains(key) {

            NSUserDefaults.standardUserDefaults().addObserver(self, forKeyPath: key, options: .New, context: nil)
            self.registeredObservationKeys.append(key)

        }

        Zephyr.printObservationStatus(key, subscribed: true)
    }

    /**

     Removes key-value observation before synchronization of a specific key.

     - parameter key: The key that should be removed from being monitored.

     */
    private func unregisterObserver(key: String) {

        if key == ZephyrSyncKey {
            return
        }

        if let index = self.registeredObservationKeys.indexOf(key) {

            NSUserDefaults.standardUserDefaults().removeObserver(self, forKeyPath: key, context: nil)
            self.registeredObservationKeys.removeAtIndex(index)

        }

        Zephyr.printObservationStatus(key, subscribed: false)
    }

    /**

     Observation method for UIApplicationWillEnterForegroundNotification

     */

    func willEnterForeground(notification: NSNotification) {
        NSUbiquitousKeyValueStore.defaultStore().synchronize()
    }

    /**

     Observation method for NSUbiquitousKeyValueStoreDidChangeExternallyNotification

     */
    func keysDidChangeOnCloud(notification: NSNotification) {
        if notification.name == NSUbiquitousKeyValueStoreDidChangeExternallyNotification {

            guard let userInfo = notification.userInfo,
                cloudKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
                localStoredDate = zephyrLocalStoreDictionary[ZephyrSyncKey] as? NSDate,
                remoteStoredDate = zephyrRemoteStoreDictionary[ZephyrSyncKey] as? NSDate where remoteStoredDate.timeIntervalSince1970 > localStoredDate.timeIntervalSince1970 else {
                    return
            }

            for key in monitoredKeys where cloudKeys.contains(key) {
                self.syncSpecificKeys([key], dataStore: .Remote)
            }
        }
    }

    override public func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {

        guard let keyPath = keyPath, object = object else {
            return
        }

        // Synchronize changes if key is monitored and if key is currently registered to respond to changes
        if monitoredKeys.contains(keyPath) {

            dispatch_async(zephyrQueue, {
                if self.registeredObservationKeys.contains(keyPath) {
                    if object is NSUserDefaults {
                        NSUserDefaults.standardUserDefaults().setObject(NSDate(), forKey: self.ZephyrSyncKey)
                    }

                    self.syncSpecificKeys([keyPath], dataStore: .Local)
                }
            })

        }

    }

}

// MARK: Loggers

private extension Zephyr {

    /**

     Prints Zephyr's current sync status if

     debugEnabled == true

     - parameter finished: The current status of syncing

     */
    static func printGeneralSyncStatus(finished: Bool, destination dataStore: ZephyrDataStore) {

        if debugEnabled == true {
            let destination = dataStore == .Local ? "FROM iCloud" : "TO iCloud."

            var message = "Started synchronization \(destination)"
            if finished == true {
                message = "Finished synchronization \(destination)"
            }

            printStatus(message)
        }
    }

    /**

     Prints the key, value, and destination of the synchronized information if

     debugEnabled == true

     - parameter key: The key being synchronized.
     - parameter value: The value being synchronized.
     - parameter destination: The data store that is receiving the updated key-value pair.

     */
    static func printKeySyncStatus(key: String, value: AnyObject?, destination dataStore: ZephyrDataStore) {

        if debugEnabled == true {
            let destination = dataStore == .Local ? "FROM iCloud" : "TO iCloud."

            guard let value = value else {
                let message = "Synchronized key '\(key)' with value 'nil' \(destination)"
                printStatus(message)
                return
            }
            
            let message = "Synchronized key '\(key)' with value '\(value)' \(destination)"
            printStatus(message)
        }
    }
    
    /**
     
     Prints the subscription state for a specific key if
     
     debugEnabled == true
     
     - parameter key: The key being synchronized.
     - parameter subscribed: The subscription status of the key.
     
     */
    static func printObservationStatus(key: String, subscribed: Bool) {
        
        if debugEnabled == true {
            let subscriptionState = subscribed == true ? "Subscribed" : "Unsubscribed"
            let preposition = subscribed == true ? "for" : "from"
            
            let message = "\(subscriptionState) '\(key)' \(preposition) observation."
            printStatus(message)
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
