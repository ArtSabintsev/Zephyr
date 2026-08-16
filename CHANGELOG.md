# Changelog

## 5.0.1

- Inbound iCloud events only touch **monitored** keys. An empty monitored set is a no-op, not a whole-domain reconcile. A missing changed-keys list (initial sync) still stays inside the monitored set.

## 5.0.0

Breaking rewrite of the sync algorithm. The 4.x store-level date stamp could pin `Zephyr.sync()` to iCloud after the second call and silently revert local edits.

### Breaking

- Full `sync()` copies the **app persistent domain** only, not `UserDefaults.dictionaryRepresentation()`. System keys (`AppleLanguages`, `AppleLocale`, …) and registered defaults are no longer uploaded.
- Conflict resolution is **per key**, using logical generations. A single wall-clock `ZephyrSyncKey` is no longer used to pick a winner.
- Absence is not a delete. Deletes propagate only via tombstones (a monitored key removed from `UserDefaults`, then synced).
- `keysDidChangeOnCloudNotification` is posted on the **main queue**, once per batch, with `userInfo[Zephyr.changedKeysUserInfoKey]` = `[String]`.
- `setUserDefaultsSuite(to:)` takes an optional `suiteName`. Pass the app-group identifier so full sync can see that domain.
- `sync(keys:userDefaults:)` no longer defaults `userDefaults` in a way that could collide with the no-suite overloads; pass the suite explicitly.

### Fixed

- `Zephyr.sync()` no longer permanently prefers iCloud after the second call.
- `Zephyr.sync(keys:)` no longer flip-flops direction by call parity.
- `sync()` returns only after pull writes have landed.
- Monitoring uses `UserDefaults.didChangeNotification`, so dotted keys (`com.example.theme`) work and no longer crash via KVO key paths.
- iCloud change reasons are handled (quota, account switch, initial sync).
- `synchronize()` runs once per batch, not once per key.
- Foreground observer is registered once (application, not application + every scene).

### Added

- Test target covering merge decisions (the 4.x revert, absence-as-delete, tombstones, dotted keys, per-key independence).
- CI runs `swift test` and pins Xcode 16.4.
