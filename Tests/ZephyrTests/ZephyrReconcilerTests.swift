import XCTest
@testable import Zephyr

final class ZephyrReconcilerTests: XCTestCase {

    func testUnmonitoredLocalEditIsNotReverted() {
        // The v4 two-launch revert: after a push, a later local edit must still push.
        var local = ZephyrSnapshot(values: ["UserSetting": "A"], versions: ["UserSetting": 1])
        let remote = ZephyrSnapshot(values: ["UserSetting": "A"], versions: ["UserSetting": 1])

        XCTAssertEqual(
            ZephyrReconciler.decide(key: "UserSetting", local: local, remote: remote),
            .skip
        )

        local.values["UserSetting"] = "B"

        XCTAssertEqual(
            ZephyrReconciler.decide(key: "UserSetting", local: local, remote: remote, mismatch: .preferLocal),
            .pushValue
        )
        XCTAssertNotEqual(
            ZephyrReconciler.decide(key: "UserSetting", local: local, remote: remote, mismatch: .preferLocal),
            .pullValue
        )
    }

    func testSpecificKeyFlipFlopIsGone() {
        let local = ZephyrSnapshot(values: ["UserSetting": "v1"], versions: ["UserSetting": 2])
        let remote = ZephyrSnapshot(values: ["UserSetting": "v1"], versions: ["UserSetting": 2])
        XCTAssertEqual(ZephyrReconciler.decide(key: "UserSetting", local: local, remote: remote), .skip)

        var localEdited = local
        localEdited.values["UserSetting"] = "v2"
        XCTAssertEqual(
            ZephyrReconciler.decide(key: "UserSetting", local: localEdited, remote: remote, mismatch: .preferLocal),
            .pushValue
        )
    }

    func testAbsenceIsNotDelete() {
        let local = ZephyrSnapshot(values: ["Sound": "off"], versions: ["Theme": 1])
        let remote = ZephyrSnapshot(values: ["Theme": "dark"], versions: ["Theme": 1])

        XCTAssertEqual(ZephyrReconciler.decide(key: "Sound", local: local, remote: remote), .pushValue)
        XCTAssertEqual(ZephyrReconciler.decide(key: "Theme", local: local, remote: remote), .pullValue)
        XCTAssertNotEqual(ZephyrReconciler.decide(key: "Sound", local: local, remote: remote), .pullDelete)
        XCTAssertNotEqual(ZephyrReconciler.decide(key: "Sound", local: local, remote: remote), .pushDelete)
    }

    func testTombstonePropagatesDelete() {
        let local = ZephyrSnapshot(
            values: [:],
            versions: [:],
            tombstones: ["Theme": 5]
        )
        let remote = ZephyrSnapshot(
            values: ["Theme": "dark"],
            versions: ["Theme": 2]
        )
        XCTAssertEqual(ZephyrReconciler.decide(key: "Theme", local: local, remote: remote), .pushDelete)
    }

    func testNewerRemoteTombstoneDeletesLocal() {
        let local = ZephyrSnapshot(values: ["Theme": "dark"], versions: ["Theme": 2])
        let remote = ZephyrSnapshot(values: [:], versions: [:], tombstones: ["Theme": 5])
        XCTAssertEqual(ZephyrReconciler.decide(key: "Theme", local: local, remote: remote), .pullDelete)
    }

    func testStaleTombstoneDoesNotWin() {
        let local = ZephyrSnapshot(values: ["Theme": "light"], versions: ["Theme": 6])
        let remote = ZephyrSnapshot(values: [:], versions: [:], tombstones: ["Theme": 5])
        XCTAssertEqual(ZephyrReconciler.decide(key: "Theme", local: local, remote: remote), .pushValue)
    }

    func testMetadataKeysNeverMerge() {
        for key in ZephyrReconciler.metadataKeys {
            let local = ZephyrSnapshot(values: [key: "x"], versions: [key: 9])
            let remote = ZephyrSnapshot()
            XCTAssertEqual(ZephyrReconciler.decide(key: key, local: local, remote: remote), .skip)
        }
    }

    func testDottedKeysAreOrdinaryKeys() {
        let local = ZephyrSnapshot(values: ["com.example.theme": "dark"], versions: [:])
        let remote = ZephyrSnapshot()
        XCTAssertEqual(
            ZephyrReconciler.decide(key: "com.example.theme", local: local, remote: remote),
            .pushValue
        )

        let previous: [String: AnyHashable?] = ["com.example.theme": "dark"]
        let current: [String: AnyHashable?] = ["com.example.theme": "light"]
        let diff = ZephyrReconciler.changedMonitoredKeys(
            previous: previous,
            current: current,
            monitored: ["com.example.theme"]
        )
        XCTAssertEqual(diff.updated, ["com.example.theme"])
        XCTAssertTrue(diff.deleted.isEmpty)
    }

    func testMonitoredSnapshotDetectsDelete() {
        let previous: [String: AnyHashable?] = ["Theme": "dark"]
        let current: [String: AnyHashable?] = ["Theme": nil]
        let diff = ZephyrReconciler.changedMonitoredKeys(
            previous: previous,
            current: current,
            monitored: ["Theme"]
        )
        XCTAssertEqual(diff.deleted, ["Theme"])
        XCTAssertTrue(diff.updated.isEmpty)
    }

    func testLogicalClockIgnoresWallTime() {
        let local = ZephyrSnapshot(values: ["K": "new"], versions: ["K": 10])
        let remote = ZephyrSnapshot(values: ["K": "old"], versions: ["K": 3])
        XCTAssertEqual(ZephyrReconciler.decide(key: "K", local: local, remote: remote), .pushValue)

        let behind = ZephyrSnapshot(values: ["K": "old"], versions: ["K": 3])
        let ahead = ZephyrSnapshot(values: ["K": "new"], versions: ["K": 10])
        XCTAssertEqual(ZephyrReconciler.decide(key: "K", local: behind, remote: ahead), .pullValue)
    }

    func testNextGenerationIsMonotonic() {
        let local = ZephyrSnapshot(versions: ["A": 4], tombstones: ["B": 7])
        let remote = ZephyrSnapshot(versions: ["C": 2])
        XCTAssertEqual(ZephyrReconciler.nextGeneration(local: local, remote: remote), 8)
    }

    func testV4MigrationDoesNotClobberEqualUnknownValues() {
        let local = ZephyrSnapshot(values: ["Theme": "dark"])
        let remote = ZephyrSnapshot(values: ["Theme": "dark"])
        XCTAssertEqual(ZephyrReconciler.decide(key: "Theme", local: local, remote: remote), .skip)
    }

    func testV4MigrationPushesLocalOnlyKey() {
        let local = ZephyrSnapshot(values: ["Theme": "dark"])
        let remote = ZephyrSnapshot()
        XCTAssertEqual(ZephyrReconciler.decide(key: "Theme", local: local, remote: remote), .pushValue)
    }

    func testV4MigrationPullsRemoteOnlyKey() {
        let local = ZephyrSnapshot()
        let remote = ZephyrSnapshot(values: ["Theme": "dark"])
        XCTAssertEqual(ZephyrReconciler.decide(key: "Theme", local: local, remote: remote), .pullValue)
    }

    func testCloudMismatchPrefersRemote() {
        let local = ZephyrSnapshot(values: ["Theme": "dark"], versions: ["Theme": 1])
        let remote = ZephyrSnapshot(values: ["Theme": "light"], versions: ["Theme": 1])
        XCTAssertEqual(
            ZephyrReconciler.decide(key: "Theme", local: local, remote: remote, mismatch: .preferRemote),
            .pullValue
        )
    }

    func testIndependentKeysDoNotClobberEachOther() {
        let local = ZephyrSnapshot(
            values: ["theme": "dark", "font": "sans"],
            versions: ["theme": 5, "font": 1]
        )
        let remote = ZephyrSnapshot(
            values: ["theme": "light", "font": "serif"],
            versions: ["theme": 2, "font": 4]
        )
        XCTAssertEqual(ZephyrReconciler.decide(key: "theme", local: local, remote: remote), .pushValue)
        XCTAssertEqual(ZephyrReconciler.decide(key: "font", local: local, remote: remote), .pullValue)
    }

    func testMergedMetadataFollowsWinner() {
        let local = ZephyrSnapshot(values: ["theme": "dark"], versions: ["theme": 5])
        let remote = ZephyrSnapshot(values: ["theme": "light"], versions: ["theme": 2])
        let merged = ZephyrReconciler.mergedMetadata(local: local, remote: remote, keys: ["theme"])
        XCTAssertEqual(merged.versions["theme"], 5)
        XCTAssertNil(merged.tombstones["theme"])
    }

    func testLimitedMetadataWriteDoesNotDropOtherKeys() {
        let persisted = ZephyrReconciler.persistMetadata(
            existingVersions: ["theme": 5, "font": 3],
            existingTombstones: ["sound": 7],
            existingKnown: ["theme", "font", "sound"],
            updateVersions: ["theme": 6],
            updateTombstones: [:],
            updateKnown: ["theme"]
        )
        XCTAssertEqual(persisted.versions["theme"], 6)
        XCTAssertEqual(persisted.versions["font"], 3)
        XCTAssertNil(persisted.versions["sound"])
        XCTAssertEqual(persisted.tombstones["sound"], 7)
        XCTAssertEqual(persisted.known, ["theme", "font", "sound"])
    }

    func testLimitedTombstoneDoesNotDropVersions() {
        let persisted = ZephyrReconciler.persistMetadata(
            existingVersions: ["theme": 5, "font": 3],
            existingTombstones: [:],
            existingKnown: ["theme", "font"],
            updateVersions: [:],
            updateTombstones: ["font": 8],
            updateKnown: ["font"]
        )
        XCTAssertEqual(persisted.versions["theme"], 5)
        XCTAssertNil(persisted.versions["font"])
        XCTAssertEqual(persisted.tombstones["font"], 8)
    }

    func testPersistBothSidesDoesNotImportUnappliedRemoteGeneration() {
        let sides = ZephyrReconciler.persistBothSides(
            localVersions: ["theme": 1],
            localTombstones: [:],
            localKnown: ["theme", "sound"],
            remoteVersions: ["theme": 1, "sound": 7],
            remoteTombstones: [:],
            remoteKnown: ["theme", "sound"],
            updateVersions: ["theme": 2],
            updateTombstones: [:],
            updateKnown: ["theme"]
        )
        XCTAssertEqual(sides.local.versions["theme"], 2)
        XCTAssertNil(sides.local.versions["sound"], "must not import unapplied remote gen")
        XCTAssertEqual(sides.remote.versions["sound"], 7)
        XCTAssertEqual(sides.remote.versions["theme"], 2)
    }

    func testPersistBothSidesDoesNotImportUnappliedRemoteTombstone() {
        let sides = ZephyrReconciler.persistBothSides(
            localVersions: ["theme": 1, "sound": 2],
            localTombstones: [:],
            localKnown: ["theme", "sound"],
            remoteVersions: ["theme": 1],
            remoteTombstones: ["sound": 5],
            remoteKnown: ["theme", "sound"],
            updateVersions: ["theme": 1],
            updateTombstones: [:],
            updateKnown: ["theme"]
        )
        XCTAssertEqual(sides.local.versions["sound"], 2)
        XCTAssertNil(sides.local.tombstones["sound"])
        XCTAssertEqual(sides.remote.tombstones["sound"], 5)
    }

    func testInboundLimitDoesNothingWhenNothingIsMonitored() {
        XCTAssertTrue(ZephyrReconciler.inboundLimit(cloudKeys: [], monitoredKeys: []).isEmpty)
        XCTAssertTrue(
            ZephyrReconciler.inboundLimit(
                cloudKeys: ["Theme", "Sound"],
                monitoredKeys: []
            ).isEmpty
        )
    }

    func testInboundLimitWithoutChangedKeysStaysInsideMonitoredSet() {
        let limited = ZephyrReconciler.inboundLimit(
            cloudKeys: [],
            monitoredKeys: ["Theme", ZephyrReconciler.versionsKey]
        )
        XCTAssertEqual(limited, ["Theme"])
    }

    func testInboundLimitIntersectsChangedKeysWithMonitoredSet() {
        let limited = ZephyrReconciler.inboundLimit(
            cloudKeys: ["Theme", "Sound", ZephyrReconciler.versionsKey],
            monitoredKeys: ["Theme"]
        )
        XCTAssertEqual(limited, ["Theme"])
    }

    func testInboundLimitIgnoresUnmonitoredChangedKeys() {
        let limited = ZephyrReconciler.inboundLimit(
            cloudKeys: ["Sound"],
            monitoredKeys: ["Theme"]
        )
        XCTAssertTrue(limited.isEmpty)
    }

    func testUniverseIncludesExplicitNewKey() {
        let local = ZephyrSnapshot()
        let remote = ZephyrSnapshot()
        let keys = ZephyrReconciler.universe(local: local, remote: remote, limitedTo: ["Sound"])
        XCTAssertTrue(keys.contains("Sound"))
        XCTAssertFalse(keys.contains(ZephyrReconciler.versionsKey))
    }
}
