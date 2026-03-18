import SwiftUI
import AppKit

// MARK: - ObjC bridge for EMRAppDelegate

@objc protocol SettingsViewDelegate: AnyObject {
    func settingsDidChangeModifiers()
    func settingsDidChangeMouseButton()
    func settingsDidToggleHoverMode()
    func settingsDidReset()
    func settingsDidQuit()
}

@available(macOS 13.0, *)
@objc class SettingsViewBridge: NSObject {
    @objc let viewController: NSViewController
    @objc weak var delegate: SettingsViewDelegate?

    @objc init(preferences: Preferences) {
        let callbacks = SettingsCallbacks()
        let view = SettingsView(preferences: preferences, callbacks: callbacks)
        let hosting = NSHostingController(rootView: view)
        hosting.sizingOptions = .preferredContentSize
        self.viewController = hosting
        super.init()

        // Rewire callbacks to delegate after init
        var updatedView = view
        updatedView.callbacks = SettingsCallbacks(
            onModifierChanged: { [weak self] in self?.delegate?.settingsDidChangeModifiers() },
            onMouseButtonChanged: { [weak self] in self?.delegate?.settingsDidChangeMouseButton() },
            onHoverModeToggled: { [weak self] in self?.delegate?.settingsDidToggleHoverMode() },
            onReset: { [weak self] in self?.delegate?.settingsDidReset() },
            onQuit: { [weak self] in self?.delegate?.settingsDidQuit() }
        )
        hosting.rootView = updatedView
    }

    @objc func syncFromPreferences() {
        guard let hosting = viewController as? NSHostingController<SettingsView> else { return }
        var view = hosting.rootView
        view.syncFromPreferences()
        hosting.rootView = view
    }
}

@available(macOS 13.0, *)
struct SettingsCallbacks {
    var onModifierChanged: () -> Void = {}
    var onMouseButtonChanged: () -> Void = {}
    var onHoverModeToggled: () -> Void = {}
    var onReset: () -> Void = {}
    var onQuit: () -> Void = {}
}

@available(macOS 13.0, *)
struct SettingsView: View {
    let preferences: Preferences
    var callbacks = SettingsCallbacks()

    @State var moveFlags: Set<String> = []
    @State var resizeFlags: Set<String> = []
    @State var moveButton: Int = 0
    @State var resizeButton: Int = 0
    @State var hoverMode = false
    @State var bringToFront = false
    @State var resizeOnly = false
    @State var hasConflict = false

    static let modifierKeys: [(label: String, key: String)] = [
        ("fn", "FN"),
        ("\u{2303}", "CTRL"),
        ("\u{2325}", "ALT"),
        ("\u{21E7}", "SHIFT"),
        ("\u{2318}", "CMD"),
    ]

    static let mouseButtons: [(label: String, tag: Int)] = [
        ("Left", 0),
        ("Right", 1),
        ("Middle", 2),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            titleSection
            moveSection
            resizeSection
            conflictSection
            togglesSection
            Divider()
            buttonsSection
        }
        .padding(16)
        .frame(width: 320)
        .onAppear { syncFromPreferences() }
    }

    // MARK: - Sections

    private var titleSection: some View {
        Group {
            Text("Zooom3").font(.system(size: 14, weight: .bold))
            Divider()
        }
    }

    private var moveSection: some View {
        Group {
            Text("Movement shortcut:")
            ModifierRow(flags: $moveFlags, prefix: "move", onChange: { applyMoveFlags() })
            MouseButtonRow(selection: $moveButton, identifier: "moveMouseButton", disabled: hoverMode, onChange: {
                preferences.setMoveMouseButton(moveButton)
                updateConflict()
                callbacks.onMouseButtonChanged()
            })
            Divider()
        }
    }

    private var resizeSection: some View {
        Group {
            Text("Resize shortcut:")
            ModifierRow(flags: $resizeFlags, prefix: "resize", onChange: { applyResizeFlags() })
            MouseButtonRow(selection: $resizeButton, identifier: "resizeMouseButton", disabled: hoverMode, onChange: {
                preferences.setResizeMouseButton(resizeButton)
                updateConflict()
                callbacks.onMouseButtonChanged()
            })
            Divider()
        }
    }

    @ViewBuilder
    private var conflictSection: some View {
        if hasConflict {
            Text("\u{26A0}\u{FE0F} Shortcuts are conflicting")
                .foregroundColor(.red)
                .accessibilityIdentifier("conflictWarning")
            Divider()
        }
    }

    private var togglesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Hover to Move/Resize (no click)", isOn: $hoverMode)
                .accessibilityIdentifier("hoverMode")
                .onChange(of: hoverMode) { _ in
                    preferences.hoverModeEnabled = hoverMode
                    updateConflict()
                    callbacks.onHoverModeToggled()
                }
            Toggle("Bring window to front", isOn: $bringToFront)
                .accessibilityIdentifier("bringToFront")
                .onChange(of: bringToFront) { _ in
                    preferences.shouldBringWindowToFront = bringToFront
                }
            Toggle("Resize only", isOn: $resizeOnly)
                .accessibilityIdentifier("resizeOnly")
                .onChange(of: resizeOnly) { _ in
                    preferences.resizeOnly = resizeOnly
                }
        }
    }

    private var buttonsSection: some View {
        HStack {
            Button("Reset to Defaults") {
                callbacks.onReset()
                syncFromPreferences()
            }
            .accessibilityIdentifier("resetToDefaults")
            Spacer()
            Button("Quit") {
                callbacks.onQuit()
            }
            .accessibilityIdentifier("quit")
        }
    }

    // MARK: - Sync

    func syncFromPreferences() {
        moveFlags = preferences.moveFlagStringSet
        resizeFlags = preferences.resizeFlagStringSet
        moveButton = preferences.moveMouseButton.rawValue
        resizeButton = preferences.resizeMouseButton.rawValue
        hoverMode = preferences.hoverModeEnabled
        bringToFront = preferences.shouldBringWindowToFront
        resizeOnly = preferences.resizeOnly
        hasConflict = preferences.hasConflictingConfig
    }

    private func applyMoveFlags() {
        let current = preferences.moveFlagStringSet
        for mod in Self.modifierKeys {
            let shouldBeOn = moveFlags.contains(mod.key)
            let isOn = current.contains(mod.key)
            if shouldBeOn != isOn {
                preferences.setMoveModifier(mod.key, enabled: shouldBeOn)
            }
        }
        updateConflict()
        callbacks.onModifierChanged()
    }

    private func applyResizeFlags() {
        let current = preferences.resizeFlagStringSet
        for mod in Self.modifierKeys {
            let shouldBeOn = resizeFlags.contains(mod.key)
            let isOn = current.contains(mod.key)
            if shouldBeOn != isOn {
                preferences.setResizeModifier(mod.key, enabled: shouldBeOn)
            }
        }
        updateConflict()
        callbacks.onModifierChanged()
    }

    private func updateConflict() {
        hasConflict = preferences.hasConflictingConfig
    }
}

// MARK: - Reusable subviews

@available(macOS 13.0, *)
struct ModifierRow: View {
    @Binding var flags: Set<String>
    let prefix: String
    var onChange: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            ForEach(SettingsView.modifierKeys, id: \.key) { mod in
                Toggle(mod.label, isOn: Binding(
                    get: { flags.contains(mod.key) },
                    set: { isOn in
                        if isOn { flags.insert(mod.key) }
                        else { flags.remove(mod.key) }
                        onChange()
                    }
                ))
                .toggleStyle(.checkbox)
                .accessibilityIdentifier("\(prefix).\(mod.key)")
            }
        }
    }
}

@available(macOS 13.0, *)
struct MouseButtonRow: View {
    @Binding var selection: Int
    let identifier: String
    let disabled: Bool
    var onChange: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            Text("Mouse button:")
            Picker("", selection: $selection) {
                ForEach(SettingsView.mouseButtons, id: \.tag) { btn in
                    Text(btn.label).tag(btn.tag)
                }
            }
            .labelsHidden()
            .accessibilityIdentifier(identifier)
            .disabled(disabled)
            .onChange(of: selection) { _ in onChange() }
        }
    }
}
