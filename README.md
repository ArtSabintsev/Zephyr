# Zephyr

### Effortlessly sync NSUserDefaults over iCloud

---
### About

Zephyr synchronizes specific keys and/or all of your [NSUserDefaults](https://developer.apple.com/library/ios/documentation/Cocoa/Reference/Foundation/Classes/NSUserDefaults_Class/) over iCloud using [NSUbiquitousKeyValueStore](https://developer.apple.com/library/ios/documentation/Foundation/Reference/NSUbiquitousKeyValueStore_class/).

Zephyr also has built in monitoring, allowing it to magically sync specific keys in the background as they change.

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

To sync all NSUserDefaults:
```Swift
Zephyr.sync()
```

To sync a specific key or keys, simply pass those key/keys to the variadic function:
```Swift
Zephyr.sync("MyFirstKey", "MySecondKey", ...)
```

For background monitoring of specific keys, simply pass the keys you want to the variadic function:

```Swift
Zephyr.addKeysToBeMonitored("MyFirstKey", "MySecondKey", ...)
```

Similarly, to remove background monitoring, simply pass the keys you want to this variadic function:
```Swift
Zephyr.removeKeysFromBeingMonitored("MyFirstKey", "MySecondKey", ...)
```

To see log statements in your console, you can set `debugEnabled = true` before calling `sync()`:
```Swift
Zephyr.debugEnabled = true
Zephyr.sync()
```

### Created and maintained by
[Arthur Ariel Sabintsev](http://www.sabintsev.com/)
