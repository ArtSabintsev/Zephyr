# Zephyr

### Effortlessly sync NSUserDefaults over iCloud

---
### About

Zephyr synchronizes specific keys and/or all of your [NSUserDefaults](https://developer.apple.com/library/ios/documentation/Cocoa/Reference/Foundation/Classes/NSUserDefaults_Class/) over iCloud using [NSUbiquitousKeyValueStore](https://developer.apple.com/library/ios/documentation/Foundation/Reference/NSUbiquitousKeyValueStore_class/).

Zephyr has built in monitoring, allowing it to sync specific keys in the background as they change.

For the latest updates, refer to the [Releases](https://github.com/ArtSabintsev/Zephyr/releases) tab.

### Features
- [x] CocoaPods Support
- [x] Syncs all your NSUserDefaults (if you wish)
- [x] Syncs only specific keys in NSUserDefaults
- [x] Background monitoring and synchronization between NSUserDefaults and NSUbiquitousKeyValueStore
- [x] Detailed Logging

### Installation Instructions

#### CocoaPods Installation
```ruby
pod 'Zephyr'
```
- Add `import Zephyr` to any `.Swift` file that references Zephyr via a CocoaPods installation.

#### Manual Installation

1. [Download Zephyr](http://github.com/ArtSabintsev/Zephyr/archive/master.zip)
2. Copy `Zephyr.swift` into your project.

### Setup

#### Turn on iCloud Sync in Xcode
In Xcode, open your app's project/workspace file:
- Click on your Project
- Click on one of your Targets
- Click on Capabilities
- Turn on iCloud syncing
- Under Services, make sure to check `Key-value storage`
- Repeat for all Targets (if necessary)

![How to turn on iCloud Key Value Store Syncing](https://github.com/ArtSabintsev/Zephyr/blob/master/screenshot.png?raw=true "How to turn on iCloud Key Value Store Syncing")

#### Integrate Zephyr into your App

Before performing each sync, Zephyr automatically checks to see if the data in NSUserDefaults or NSUbiquitousKeyValueStore is newer. To make sure there's no overwriting going on in a fresh installation of your app on a new device that's connected to the same iCloud account, make sure that your NSUserDefaults are registered ***BEFORE*** calling any of the Zephyr methods.

***
#####Choose to Sync All Keys or Select Keys

Syncing ***ALL*** NSUserDefaults will sync every key, including those that aren't related to your application. This can cause issues so unless you have a reason to sync every key, you should choose to sync only those keys requiring iCloud sync for your app.

**Sync all NSUserDefaults**
```Swift
Zephyr.sync()
```

**Sync a specific key or keys (Variadic Option)**
```Swift
Zephyr.sync("MyFirstKey", "MySecondKey", ...)
```

**Sync a specific key or keys (Array Option)**
```Swift
Zephyr.sync(["MyFirstKey", "MySecondKey"])
```

***
#####Enable Background Monitoring of Key Changes (Optional)

If you want your application to synchronize keys while the app is running and not just once when the Zephyr.sync() method is called, then add background monitoring.

**Add/Remove Keys for Background Monitoring (Variadic Option)**

```Swift
Zephyr.addKeysToBeMonitored("MyFirstKey", "MySecondKey", ...)
Zephyr.removeKeysFromBeingMonitored("MyFirstKey", "MySecondKey", ...)
```

**Add/Remove Keys for Background Monitoring (Array Option)**
```Swift
Zephyr.addKeysToBeMonitored(["MyFirstKey", "MySecondKey"])
Zephyr.removeKeysFromBeingMonitored(["MyFirstKey", "MySecondKey"])
```

***
#####Toggle Automatic Calling of NSUbiquitousKeyValueStore's Synchronization method (Optional)

```
Zephyr.syncUbiquitousStoreKeyValueStoreOnChange = true // Default
Zephyr.syncUbiquitousStoreKeyValueStoreOnChange = false // Turns off instantaneous synchronization
```

***
#####Debug Logging (Optional)

All changes that Zephyr processes will print to the console. Use this to see the key/value pairs being read FROM and TO iCloud by Zephyr.

```Swift
Zephyr.debugEnabled = true // Must be called before sync(_:)
Zephyr.sync()
```

### Created and maintained by
[Arthur Ariel Sabintsev](http://www.sabintsev.com/)
