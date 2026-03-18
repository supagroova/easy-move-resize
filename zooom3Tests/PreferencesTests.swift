import XCTest
@testable import Zooom3

final class PreferencesTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!
    private var preferences: Preferences!

    override func setUp() {
        super.setUp()
        suiteName = "com.supagroova.zooom3.test.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        preferences = Preferences(userDefaults: defaults)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Helper: create v1 preferences to test migration

    private func createV1Preferences(modifiers: String, middleClick: Bool) -> Preferences {
        let suite = "com.supagroova.zooom3.test.v1.\(UUID().uuidString)"
        let defs = UserDefaults(suiteName: suite)!
        defs.set(modifiers, forKey: Preferences.Keys.modifierFlags)
        defs.set(middleClick, forKey: Preferences.Keys.middleClickResize)
        defs.set([String: String](), forKey: Preferences.Keys.disabledApps)
        return Preferences(userDefaults: defs)
    }

    // MARK: - Move modifier reset

    func testResetPreferences() {
        preferences.resetToDefaults()
        var flags = preferences.moveFlagStringSet
        XCTAssertEqual(flags, Set(["CTRL", "CMD"]))

        preferences.setMoveModifier("CTRL", enabled: false)
        flags = preferences.moveFlagStringSet
        XCTAssertEqual(flags, Set(["CMD"]))

        preferences.resetToDefaults()
        flags = preferences.moveFlagStringSet
        XCTAssertEqual(flags, Set(["CMD", "CTRL"]))
    }

    // MARK: - Resize modifier flags

    func testResizeModifierDefaults() {
        preferences.resetToDefaults()
        let resizeFlags = preferences.resizeFlagStringSet
        XCTAssertEqual(resizeFlags, Set(["CTRL", "CMD"]))
    }

    func testSetResizeModifierKey() {
        preferences.resetToDefaults()

        preferences.setResizeModifier("ALT", enabled: true)
        var resizeFlags = preferences.resizeFlagStringSet
        XCTAssertTrue(resizeFlags.contains("ALT"))
        XCTAssertTrue(resizeFlags.contains("CMD"))
        XCTAssertTrue(resizeFlags.contains("CTRL"))

        preferences.setResizeModifier("CTRL", enabled: false)
        resizeFlags = preferences.resizeFlagStringSet
        XCTAssertFalse(resizeFlags.contains("CTRL"))
        XCTAssertTrue(resizeFlags.contains("ALT"))
        XCTAssertTrue(resizeFlags.contains("CMD"))
    }

    func testResizeModifierFlagsReturnsCorrectBitmask() {
        preferences.resetToDefaults()
        var flags = preferences.resizeModifierFlags
        let expected = CGEventFlags.maskCommand.rawValue | CGEventFlags.maskControl.rawValue
        XCTAssertEqual(flags, Int32(expected))

        preferences.setResizeModifier("CMD", enabled: false)
        preferences.setResizeModifier("CTRL", enabled: false)
        preferences.setResizeModifier("ALT", enabled: true)
        flags = preferences.resizeModifierFlags
        XCTAssertEqual(flags, Int32(CGEventFlags.maskAlternate.rawValue))
    }

    func testMoveAndResizeModifiersAreIndependent() {
        preferences.resetToDefaults()

        preferences.setMoveModifier("CTRL", enabled: false)
        preferences.setResizeModifier("CTRL", enabled: false)
        preferences.setResizeModifier("ALT", enabled: true)

        let moveFlags = preferences.moveFlagStringSet
        let resizeFlags = preferences.resizeFlagStringSet

        XCTAssertEqual(moveFlags, Set(["CMD"]))
        XCTAssertEqual(resizeFlags, Set(["CMD", "ALT"]))
    }

    // MARK: - Mouse button preferences

    func testMouseButtonDefaults() {
        preferences.resetToDefaults()
        XCTAssertEqual(preferences.moveMouseButton, .left)
        XCTAssertEqual(preferences.resizeMouseButton, .right)
    }

    func testSetMoveMouseButton() {
        preferences.resetToDefaults()
        preferences.moveMouseButton = .middle
        XCTAssertEqual(preferences.moveMouseButton, .middle)
    }

    func testSetResizeMouseButton() {
        preferences.resetToDefaults()
        preferences.resizeMouseButton = .left
        XCTAssertEqual(preferences.resizeMouseButton, .left)
    }

    func testResizeMouseButtonDefaultsToRightWhenUnset() {
        let suite = "com.supagroova.zooom3.test.niltest.\(UUID().uuidString)"
        let freshDefaults = UserDefaults(suiteName: suite)!
        let freshPrefs = Preferences(userDefaults: freshDefaults)
        XCTAssertEqual(freshPrefs.resizeMouseButton, .right)
        UserDefaults.standard.removePersistentDomain(forName: suite)
    }

    // MARK: - Conflict detection

    func testNoConflictWithDefaultSettings() {
        preferences.resetToDefaults()
        XCTAssertFalse(preferences.hasConflictingConfig)
    }

    func testConflictWhenSameButtonAndSameModifiers() {
        preferences.resetToDefaults()
        preferences.moveMouseButton = .left
        preferences.resizeMouseButton = .left
        XCTAssertTrue(preferences.hasConflictingConfig)
    }

    func testNoConflictWhenSameButtonDifferentModifiers() {
        preferences.resetToDefaults()
        preferences.moveMouseButton = .left
        preferences.resizeMouseButton = .left
        preferences.setResizeModifier("ALT", enabled: true)
        preferences.setResizeModifier("CTRL", enabled: false)
        XCTAssertFalse(preferences.hasConflictingConfig)
    }

    func testNoConflictWhenDifferentButtonSameModifiers() {
        preferences.resetToDefaults()
        preferences.moveMouseButton = .left
        preferences.resizeMouseButton = .right
        XCTAssertFalse(preferences.hasConflictingConfig)
    }

    // MARK: - Preference migration from v1

    func testMigrationCopiesModifierFlagsToResize() {
        let migrated = createV1Preferences(modifiers: "CMD,ALT", middleClick: false)
        XCTAssertEqual(migrated.resizeFlagStringSet, Set(["CMD", "ALT"]))
    }

    func testMigrationMiddleClickToResizeMouseButton() {
        let migrated = createV1Preferences(modifiers: "CMD,CTRL", middleClick: true)
        XCTAssertEqual(migrated.resizeMouseButton, .middle)
    }

    func testMigrationNoMiddleClickKeepsDefaultRight() {
        let migrated = createV1Preferences(modifiers: "CMD,CTRL", middleClick: false)
        XCTAssertEqual(migrated.resizeMouseButton, .right)
    }

    func testMigrationRunsOnlyOnce() {
        let suite = "com.supagroova.zooom3.test.migrateonce.\(UUID().uuidString)"
        let defs = UserDefaults(suiteName: suite)!
        defs.set("CMD,ALT", forKey: Preferences.Keys.modifierFlags)
        defs.set(true, forKey: Preferences.Keys.middleClickResize)
        defs.set([String: String](), forKey: Preferences.Keys.disabledApps)

        let prefs1 = Preferences(userDefaults: defs)
        XCTAssertEqual(prefs1.resizeMouseButton, .middle)

        prefs1.resizeMouseButton = .left
        XCTAssertEqual(prefs1.resizeMouseButton, .left)

        // Re-init should not re-run migration
        let prefs2 = Preferences(userDefaults: defs)
        XCTAssertEqual(prefs2.resizeMouseButton, .left)

        UserDefaults.standard.removePersistentDomain(forName: suite)
    }

    // MARK: - setToDefaults comprehensive

    func testSetToDefaultsResetsAllFields() {
        preferences.resetToDefaults()

        preferences.setMoveModifier("ALT", enabled: true)
        preferences.setResizeModifier("SHIFT", enabled: true)
        preferences.moveMouseButton = .middle
        preferences.resizeMouseButton = .left
        preferences.shouldBringWindowToFront = true
        preferences.resizeOnly = true

        preferences.resetToDefaults()

        let expectedModifiers: Set<String> = ["CMD", "CTRL"]
        XCTAssertEqual(preferences.moveFlagStringSet, expectedModifiers)
        XCTAssertEqual(preferences.resizeFlagStringSet, expectedModifiers)
        XCTAssertEqual(preferences.moveMouseButton, .left)
        XCTAssertEqual(preferences.resizeMouseButton, .right)
        XCTAssertFalse(preferences.shouldBringWindowToFront)
        XCTAssertFalse(preferences.resizeOnly)
        XCTAssertFalse(preferences.hasConflictingConfig)
    }

    // MARK: - Edge cases

    func testAllModifiersUncheckedReturnsZeroFlags() {
        preferences.resetToDefaults()
        preferences.setResizeModifier("CMD", enabled: false)
        preferences.setResizeModifier("CTRL", enabled: false)
        XCTAssertEqual(preferences.resizeModifierFlags, 0)
    }

    func testAllMoveModifiersUncheckedReturnsZeroFlags() {
        preferences.resetToDefaults()
        preferences.setMoveModifier("CMD", enabled: false)
        preferences.setMoveModifier("CTRL", enabled: false)
        XCTAssertEqual(preferences.moveModifierFlags, 0)
    }

    func testConflictWithAllModifiersUnchecked() {
        preferences.resetToDefaults()
        preferences.moveMouseButton = .left
        preferences.resizeMouseButton = .left
        preferences.setMoveModifier("CMD", enabled: false)
        preferences.setMoveModifier("CTRL", enabled: false)
        preferences.setResizeModifier("CMD", enabled: false)
        preferences.setResizeModifier("CTRL", enabled: false)
        XCTAssertTrue(preferences.hasConflictingConfig)
    }

    // MARK: - Hover mode preference

    func testHoverModeDefaultsToFalse() {
        preferences.resetToDefaults()
        XCTAssertFalse(preferences.hoverModeEnabled)
    }

    func testSetHoverModeEnabled() {
        preferences.resetToDefaults()
        preferences.hoverModeEnabled = true
        XCTAssertTrue(preferences.hoverModeEnabled)
    }

    func testSetHoverModeDisabled() {
        preferences.resetToDefaults()
        preferences.hoverModeEnabled = true
        preferences.hoverModeEnabled = false
        XCTAssertFalse(preferences.hoverModeEnabled)
    }

    func testSetToDefaultsResetsHoverMode() {
        preferences.hoverModeEnabled = true
        preferences.resetToDefaults()
        XCTAssertFalse(preferences.hoverModeEnabled)
    }

    // MARK: - Conflict detection in hover mode

    func testConflictInHoverModeWithSameModifiersDifferentButtons() {
        preferences.resetToDefaults()
        preferences.hoverModeEnabled = true
        // Same modifiers (CMD+CTRL defaults) but different mouse buttons
        // In hover mode, mouse buttons are irrelevant — should conflict
        XCTAssertTrue(preferences.hasConflictingConfig)
    }

    func testNoConflictInHoverModeWithDifferentModifiers() {
        preferences.resetToDefaults()
        preferences.hoverModeEnabled = true
        preferences.setResizeModifier("ALT", enabled: true)
        preferences.setResizeModifier("CTRL", enabled: false)
        XCTAssertFalse(preferences.hasConflictingConfig)
    }

    func testNoConflictWithHoverModeOffDifferentButtons() {
        preferences.resetToDefaults()
        preferences.hoverModeEnabled = false
        XCTAssertFalse(preferences.hasConflictingConfig)
    }

    // MARK: - Disabled apps

    func testDisabledAppsDefaultsToEmpty() {
        preferences.resetToDefaults()
        XCTAssertTrue(preferences.disabledApps.isEmpty)
    }

    func testSetDisabledForApp() {
        preferences.resetToDefaults()
        preferences.setDisabled(forApp: "com.example.app", localizedName: "Example", disabled: true)
        XCTAssertEqual(preferences.disabledApps["com.example.app"], "Example")
    }

    func testRemoveDisabledApp() {
        preferences.resetToDefaults()
        preferences.setDisabled(forApp: "com.example.app", localizedName: "Example", disabled: true)
        preferences.setDisabled(forApp: "com.example.app", localizedName: "Example", disabled: false)
        XCTAssertNil(preferences.disabledApps["com.example.app"])
    }
}
