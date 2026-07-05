# Zephyr 🌬️

### Effortlessly sync UserDefaults over iCloud

![Swift Support](https://img.shields.io/badge/Swift-5.9-orange.svg) ![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%20%7C%20tvOS%2017%20%7C%20watchOS%2010-lightgray.svg?style=flat) [![SwiftPM Compatible](https://img.shields.io/badge/SwiftPM-Compatible-brightgreen.svg)](https://swift.org/package-manager/)

---
### About

Zephyr synchronizes specific keys and/or all of your [UserDefaults](https://developer.apple.com/documentation/foundation/userdefaults) over iCloud using [NSUbiquitousKeyValueStore](https://developer.apple.com/library/ios/documentation/Foundation/Reference/NSUbiquitousKeyValueStore_class/).

Zephyr has built in monitoring, allowing it to sync specific keys in the background as they change.

For the latest updates, refer to the [Releases](https://github.com/ArtSabintsev/Zephyr/releases) tab.

### Features
- [x] Swift Package Manager Support
- [x] Syncs specific `UserDefaults` keys or all of your `UserDefaults`.
- [x] Background monitoring and synchronization between `UserDefaults` and `NSUbiquitousKeyValueStore`
- [x] Detailed Logging

### Installation

Zephyr supports Swift 5.9+, iOS 17.0+, tvOS 17.0+, and watchOS 10.0+.

#### Swift Package Manager
``` swift
.package(url: "https://github.com/ArtSabintsev/Zephyr.git", from: "4.0.0")
```

#### Manual

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

![How to turn on iCloud Key Value Store Syncing](https://github.com/ArtSabintsev/Zephyr/blob/master/Assets/XcodeSettings.png?raw=true "How to turn on iCloud Key Value Store Syncing")

#### Integrate Zephyr into your App

Before performing each sync, Zephyr automatically checks to see if the data in UserDefaults or NSUbiquitousKeyValueStore is newer. To make sure there's no overwriting going on in a fresh installation of your app on a new device that's connected to the same iCloud account, make sure that your UserDefaults are registered ***BEFORE*** calling any of the Zephyr methods. One way to easily achieve this is by using the [UserDefaults Register API](https://developer.apple.com/documentation/foundation/userdefaults/1417065-register).

**Sync all UserDefaults**
```Swift
Zephyr.sync()
```

**Sync a specific key or keys (Variadic Option)**
```Swift
Zephyr.sync(keys: "MyFirstKey", "MySecondKey", ...)
```

**Sync a specific key or keys (Array Option)**
```Swift
Zephyr.sync(keys: ["MyFirstKey", "MySecondKey"])
```

**Add/Remove Keys for Background Monitoring (Variadic Option)**

```Swift
Zephyr.addKeysToBeMonitored(keys: "MyFirstKey", "MySecondKey", ...)
Zephyr.removeKeysFromBeingMonitored(keys: "MyFirstKey", "MySecondKey", ...)
```

**Add/Remove Keys for Background Monitoring (Array Option)**
```Swift
Zephyr.addKeysToBeMonitored(keys: ["MyFirstKey", "MySecondKey"])
Zephyr.removeKeysFromBeingMonitored(keys: ["MyFirstKey", "MySecondKey"])
```
**Toggle Automatic Calling of NSUbiquitousKeyValueStore's Synchronization method**
```
Zephyr.syncUbiquitousKeyValueStoreOnChange = true // Default
Zephyr.syncUbiquitousKeyValueStoreOnChange = false // Turns off instantaneous synchronization
```

**Debug Logging**
```Swift
Zephyr.debugEnabled = true // Must be called before sync(_:)
Zephyr.sync()
```

**Use a specific `UserDefaults` suite**
```swift
if let suite = UserDefaults(suiteName: "group.com.example.app-name") {
  Zephyr.setUserDefaultsSuite(to: suite)
}
```

### Created and maintained by
[Arthur Ariel Sabintsev](http://www.sabintsev.com/)
