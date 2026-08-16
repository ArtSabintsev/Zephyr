# Zephyr

### Sync UserDefaults over iCloud

[![CI](https://github.com/ArtSabintsev/Zephyr/actions/workflows/ci.yml/badge.svg)](https://github.com/ArtSabintsev/Zephyr/actions/workflows/ci.yml) ![Swift Support](https://img.shields.io/badge/Swift-5.9-orange.svg) ![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%20%7C%20tvOS%2017%20%7C%20watchOS%2010%20%7C%20macOS%2014-lightgray.svg?style=flat) [![SwiftPM Compatible](https://img.shields.io/badge/SwiftPM-Compatible-brightgreen.svg)](https://swift.org/package-manager/)

---

Zephyr synchronizes specific keys and/or your app's persistent [UserDefaults](https://developer.apple.com/documentation/foundation/userdefaults) domain over iCloud using [NSUbiquitousKeyValueStore](https://developer.apple.com/documentation/foundation/nsubiquitouskeyvaluestore).

Version **5** merges **per key** with logical generations. It does not pick one winner for the whole store. It does not upload `AppleLanguages` or other system defaults.

Requires Swift 5.9+, iOS 17, tvOS 17, watchOS 10, or macOS 14.

### Features
- [x] Swift Package Manager
- [x] Sync specific keys or the app persistent domain
- [x] Background monitoring (including dotted keys such as `com.example.theme`)
- [x] Per-key conflict resolution and tombstoned deletes
- [x] Debug logging

### Installation

```swift
.package(url: "https://github.com/ArtSabintsev/Zephyr.git", from: "5.0.1")
```

#### Manual

Copy the files in `Sources/` into your project.

### Setup

#### Turn on iCloud Key-Value storage in Xcode
- Project → Target → Signing & Capabilities → iCloud
- Enable **Key-value storage**
- Repeat for every target that syncs

![How to turn on iCloud Key Value Store Syncing](https://github.com/ArtSabintsev/Zephyr/blob/master/Assets/XcodeSettings.png?raw=true)

#### Integrate Zephyr

Register any default values **before** the first `Zephyr` call, using [`register(defaults:)`](https://developer.apple.com/documentation/foundation/userdefaults/1417065-register). Registered defaults are **not** uploaded; only keys you actually write into the persistent domain are.

`Zephyr.sync()` returns after any pulled values have been written. A read on the next line sees the merged result.

**Sync the app persistent domain**
```swift
Zephyr.sync()
```

**Sync specific keys**
```swift
Zephyr.sync(keys: "MyFirstKey", "MySecondKey")
Zephyr.sync(keys: ["MyFirstKey", "MySecondKey"])
```

**Monitor keys** (dotted names are fine)
```swift
Zephyr.addKeysToBeMonitored(keys: "MyFirstKey", "com.example.theme")
Zephyr.removeKeysFromBeingMonitored(keys: "MyFirstKey")
```

Inbound iCloud events apply **only** to monitored keys. `removeKeysFromBeingMonitored` stops inbound writes for those keys. An empty monitored set does not fall through to the whole persistent domain.

**iCloud change notification** (posted on the main queue)
```swift
NotificationCenter.default.addObserver(
    forName: Zephyr.keysDidChangeOnCloudNotification,
    object: nil,
    queue: .main
) { note in
    let keys = note.userInfo?[Zephyr.changedKeysUserInfoKey] as? [String] ?? []
    // refresh UI for `keys`
}
```

**Calling `NSUbiquitousKeyValueStore.synchronize()` after a batch**
```swift
Zephyr.syncUbiquitousKeyValueStoreOnChange = true  // default
Zephyr.syncUbiquitousKeyValueStoreOnChange = false
```

**Debug logging**
```swift
Zephyr.debugEnabled = true
Zephyr.sync()
```

**App group suite**
```swift
if let suite = UserDefaults(suiteName: "group.com.example.app-name") {
    Zephyr.setUserDefaultsSuite(to: suite, suiteName: "group.com.example.app-name")
}
```

### What 5.0 changed

See [CHANGELOG.md](CHANGELOG.md). Short version: 4.x used one date for the entire store and could revert local edits on the second `sync()`. 5.x compares a generation per key, never treats “missing” as “deleted,” and only syncs the app persistent domain.

iCloud still enforces a 1 MB / 1024-key quota on the key-value store. Two devices writing the **same** key without a generation bump are resolved by the mismatch policy (`sync()` prefers local; an inbound iCloud event prefers remote). Apple’s store remains last-writer-wins at the transport layer.

### Created and maintained by
[Arthur Ariel Sabintsev](http://www.sabintsev.com/)
