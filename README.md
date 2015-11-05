# Zephyr

### Effortlessly sync your NSUserDefaults over iCloud

---
### About

Zephyr syncs all of your [NSUserDefaults](https://developer.apple.com/library/ios/documentation/Cocoa/Reference/Foundation/Classes/NSUserDefaults_Class/), or only specific keys, over iCloud using [NSUbiquitousKeyValueStore](https://developer.apple.com/library/ios/documentation/Foundation/Reference/NSUbiquitousKeyValueStore_class/).

Zephyr also has built in monitoring, so it can sync those keys you want monitored in the background as they change.

### Changelog
#### 1.0.0
- Initial Release, which means, there might be bugs! =p

### Features
- [x] CocoaPods Support
- [x] Syncs all your NSUserDefaults (if you wish)
- [x] Syncs only specific keys in NSUserDefaults
- [x] Monitors changes to existing keys and synchronizes them between NSUserDefaults and NSUbiquitousKeyValueStore

### Installation Instructions

#### CocoaPods Installation
```ruby
pod 'Zephyr'
```
- Add `import Zephyr` to any `.Swift` file that references Zephyr via a CocoaPods installation.

#### Manual Installation

1. [Download Zephyr](http://github.com/ArtSabintsev/Zephyr/archive/master.zip).
2. Copy the `Zephyr.swift` into your project.

### Setup Xcode

In Xcode, open your project:
- Click on your project
- Click on one of your Targets
- Click on Capabilities
- Turn on iCloud Syncing
- Under Services, make sure to check `Key-value storage`

![How to turn on iCloud Key Value Store Syncing](https://github.com/ArtSabintsev/Zephyr/blob/master/screenshot.png?raw=true "How to turn on iCloud Key Value Store Syncing")

### Integrate into your App

Before performing each sync, Zephyr automatically checks to see if the data in NSUserDefaults or NSUbiquitousKeyValueStore is newer.

To sync all NSUserDefaults:
```Swift
Zephyr.sync()
```

To sync a specific key:
```Swift
Zephyr.sync("MyKey")
```

To monitor changes to specific keys in the background, simply pass the keys you want to this variadic function:

```Swift
Zephyr.addKeysToBeMonitored("MyFirstKey", "MySecondKey", ...)
```

Similarly, to remove monitoring for certain keys, simply pass the keys you want to this variadic function:
```Swift
Zephyr.removeKeysFromBeingMonitored("MyFirstKey", "MySecondKey", ...)
```

### Created and maintained by
[Arthur Ariel Sabintsev](http://www.sabintsev.com/)
