# Zephyr

### Effortlessly sync NSUserDefaults over iCloud

---
### About

Zephyr synchronizes specific keys and/or all of your [NSUserDefaults](https://developer.apple.com/library/ios/documentation/Cocoa/Reference/Foundation/Classes/NSUserDefaults_Class/) over iCloud using [NSUbiquitousKeyValueStore](https://developer.apple.com/library/ios/documentation/Foundation/Reference/NSUbiquitousKeyValueStore_class/).

Zephyr has built in monitoring, allowing it to sync specific keys in the background as they change.

### Changelog
#### 1.2.0
- Overloaded variadic `sync(_:)` method with a method that takes an array of strings.
- Overloaded variadic `addKeysToBeMonitored(_:)` method with a method that takes an array of strings.
- Overloaded variadic `removeKeysFromBeingMonitored(_:)` method with a method that takes an array of strings.
- Fixed bug with `removeKeysFromBeingMonitored(_:)`, as it was removing all keys.
- Improved monitoring by creating a second, private array that keeps track of currently registered observers.
- Greatly abstracted logging system.
- Fixed documentation on certain comments.

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

Before performing each sync, Zephyr automatically checks to see if the data in NSUserDefaults or NSUbiquitousKeyValueStore is newer.

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

**Debug Logging**
```Swift
Zephyr.debugEnabled = true // Must be called before sync(_:)
Zephyr.sync()
```

### Created and maintained by
[Arthur Ariel Sabintsev](http://www.sabintsev.com/)
