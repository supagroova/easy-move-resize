import Foundation
import CoreGraphics

enum MouseButton: Int {
    case left = 0
    case right = 1
    case middle = 2
}

@objc class Preferences: NSObject {

    // MARK: - UserDefaults keys (matching ObjC EMRPreferences.h)

    enum Keys {
        static let modifierFlags = "ModifierFlags"
        static let resizeModifierFlags = "ResizeModifierFlags"
        static let moveMouseButton = "MoveMouseButton"
        static let resizeMouseButton = "ResizeMouseButton"
        static let shouldBringWindowToFront = "BringToFront"
        static let resizeOnly = "ResizeOnly"
        static let hoverModeEnabled = "HoverModeEnabled"
        static let disabledApps = "DisabledApps"
        static let preferencesVersion = "PreferencesVersion"
        static let middleClickResize = "MiddleClickResize" // deprecated, migration only
    }

    private static let currentVersion = 2

    private static let modifierKeyMap: [(String, CGEventFlags)] = [
        ("CTRL", .maskControl),
        ("SHIFT", .maskShift),
        ("CAPS", .maskAlphaShift),
        ("ALT", .maskAlternate),
        ("CMD", .maskCommand),
        ("FN", .maskSecondaryFn),
    ]

    private let userDefaults: UserDefaults

    // MARK: - Init

    @objc init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        super.init()

        if userDefaults.string(forKey: Keys.modifierFlags) == nil {
            resetToDefaults()
        } else {
            if userDefaults.dictionary(forKey: Keys.disabledApps) == nil {
                userDefaults.set([String: String](), forKey: Keys.disabledApps)
            }

            let version = userDefaults.integer(forKey: Keys.preferencesVersion)
            if version < Self.currentVersion {
                if userDefaults.bool(forKey: Keys.middleClickResize) {
                    userDefaults.set(MouseButton.middle.rawValue, forKey: Keys.resizeMouseButton)
                }
                if let existingFlags = userDefaults.string(forKey: Keys.modifierFlags) {
                    userDefaults.set(existingFlags, forKey: Keys.resizeModifierFlags)
                }
                userDefaults.set(Self.currentVersion, forKey: Keys.preferencesVersion)
            }
        }
    }

    // MARK: - Move modifier flags

    /// Swift API returns Int32 for CGEventFlags compatibility
    var moveModifierFlags: Int32 {
        flagsFromString(userDefaults.string(forKey: Keys.modifierFlags))
    }

    /// ObjC API: `[preferences modifierFlags]` returns int
    @objc func modifierFlags() -> Int {
        Int(moveModifierFlags)
    }

    var moveFlagStringSet: Set<String> {
        flagStringSet(forKey: Keys.modifierFlags)
    }

    @objc func getFlagStringSet() -> NSSet {
        moveFlagStringSet as NSSet
    }

    func setMoveModifier(_ key: String, enabled: Bool) {
        setModifier(key, enabled: enabled, forKey: Keys.modifierFlags)
    }

    @objc func setModifierKey(_ key: String, enabled: Bool) {
        setMoveModifier(key, enabled: enabled)
    }

    // MARK: - Resize modifier flags

    var resizeModifierFlags: Int32 {
        flagsFromString(userDefaults.string(forKey: Keys.resizeModifierFlags))
    }

    @objc func resizeModifierFlagsValue() -> Int {
        Int(resizeModifierFlags)
    }

    var resizeFlagStringSet: Set<String> {
        flagStringSet(forKey: Keys.resizeModifierFlags)
    }

    @objc func getResizeFlagStringSet() -> NSSet {
        resizeFlagStringSet as NSSet
    }

    func setResizeModifier(_ key: String, enabled: Bool) {
        setModifier(key, enabled: enabled, forKey: Keys.resizeModifierFlags)
    }

    @objc func setResizeModifierKey(_ key: String, enabled: Bool) {
        setResizeModifier(key, enabled: enabled)
    }

    // MARK: - Mouse buttons

    var moveMouseButton: MouseButton {
        get { MouseButton(rawValue: userDefaults.integer(forKey: Keys.moveMouseButton)) ?? .left }
        set { userDefaults.set(newValue.rawValue, forKey: Keys.moveMouseButton) }
    }

    @objc func moveMouseButtonValue() -> Int {
        moveMouseButton.rawValue
    }

    @objc func setMoveMouseButton(_ button: Int) {
        moveMouseButton = MouseButton(rawValue: button) ?? .left
    }

    var resizeMouseButton: MouseButton {
        get {
            if userDefaults.object(forKey: Keys.resizeMouseButton) == nil {
                return .right
            }
            return MouseButton(rawValue: userDefaults.integer(forKey: Keys.resizeMouseButton)) ?? .right
        }
        set { userDefaults.set(newValue.rawValue, forKey: Keys.resizeMouseButton) }
    }

    @objc func resizeMouseButtonValue() -> Int {
        resizeMouseButton.rawValue
    }

    @objc func setResizeMouseButton(_ button: Int) {
        resizeMouseButton = MouseButton(rawValue: button) ?? .right
    }

    // MARK: - Boolean preferences

    @objc var shouldBringWindowToFront: Bool {
        get { userDefaults.bool(forKey: Keys.shouldBringWindowToFront) }
        set { userDefaults.set(newValue, forKey: Keys.shouldBringWindowToFront) }
    }

    @objc var resizeOnly: Bool {
        get { userDefaults.bool(forKey: Keys.resizeOnly) }
        set { userDefaults.set(newValue, forKey: Keys.resizeOnly) }
    }

    @objc var hoverModeEnabled: Bool {
        get { userDefaults.bool(forKey: Keys.hoverModeEnabled) }
        set { userDefaults.set(newValue, forKey: Keys.hoverModeEnabled) }
    }

    // MARK: - Conflict detection

    @objc var hasConflictingConfig: Bool {
        let sameModifiers = moveModifierFlags == resizeModifierFlags
        if hoverModeEnabled {
            return sameModifiers
        }
        if moveMouseButton != resizeMouseButton {
            return false
        }
        return sameModifiers
    }

    // MARK: - Disabled apps

    var disabledApps: [String: String] {
        (userDefaults.dictionary(forKey: Keys.disabledApps) as? [String: String]) ?? [:]
    }

    @objc func getDisabledApps() -> NSDictionary {
        disabledApps as NSDictionary
    }

    func setDisabled(forApp bundleIdentifier: String, localizedName: String, disabled: Bool) {
        var apps = disabledApps
        if disabled {
            apps[bundleIdentifier] = localizedName
        } else {
            apps.removeValue(forKey: bundleIdentifier)
        }
        userDefaults.set(apps, forKey: Keys.disabledApps)
    }

    // MARK: - Reset

    @objc func setToDefaults() { resetToDefaults() }

    func resetToDefaults() {
        setFlagString("CTRL,CMD", forKey: Keys.modifierFlags)
        setFlagString("CTRL,CMD", forKey: Keys.resizeModifierFlags)
        userDefaults.set(false, forKey: Keys.shouldBringWindowToFront)
        userDefaults.set(false, forKey: Keys.resizeOnly)
        userDefaults.set(MouseButton.left.rawValue, forKey: Keys.moveMouseButton)
        userDefaults.set(MouseButton.right.rawValue, forKey: Keys.resizeMouseButton)
        userDefaults.set(Self.currentVersion, forKey: Keys.preferencesVersion)
        userDefaults.set([String: String](), forKey: Keys.disabledApps)
        userDefaults.set(false, forKey: Keys.hoverModeEnabled)
    }

    // MARK: - Private helpers

    private func flagStringSet(forKey key: String) -> Set<String> {
        guard let raw = userDefaults.string(forKey: key), !raw.isEmpty else {
            return []
        }
        let cleaned = raw.replacingOccurrences(of: " ", with: "").uppercased()
        return Set(cleaned.components(separatedBy: ",").filter { !$0.isEmpty })
    }

    private func setModifier(_ modifier: String, enabled: Bool, forKey key: String) {
        var flags = flagStringSet(forKey: key)
        let upper = modifier.uppercased()
        if enabled {
            flags.insert(upper)
        } else {
            flags.remove(upper)
        }
        setFlagString(flags.joined(separator: ","), forKey: key)
    }

    private func setFlagString(_ value: String, forKey key: String) {
        let cleaned = value.replacingOccurrences(of: " ", with: "").uppercased()
        userDefaults.set(cleaned, forKey: key)
    }

    private func flagsFromString(_ string: String?) -> Int32 {
        guard let string, !string.isEmpty else { return 0 }
        let set = Set(string.replacingOccurrences(of: " ", with: "").uppercased().components(separatedBy: ","))
        var result: UInt64 = 0
        for (key, flag) in Self.modifierKeyMap {
            if set.contains(key) {
                result |= flag.rawValue
            }
        }
        return Int32(result)
    }
}
