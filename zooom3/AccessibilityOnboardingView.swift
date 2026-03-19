import SwiftUI
import AppKit

// MARK: - SwiftUI Onboarding View

@available(macOS 13.0, *)
struct AccessibilityOnboardingView: View {
    var onOpenSettings: () -> Void = {}

    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)

            Text("Zooom3 needs Accessibility access")
                .font(.system(size: 18, weight: .bold))
                .multilineTextAlignment(.center)

            Text("Zooom3 uses Accessibility permissions to move and resize windows with modifier keys. Enable access in System Settings to get started.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Image("AccessibilitySettings")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 420)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

            Button(action: onOpenSettings) {
                Text("Open System Settings")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("openSystemSettings")

            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Waiting for permission...")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(32)
        .frame(width: 480)
    }
}

// MARK: - ObjC Bridge

@available(macOS 13.0, *)
@objc class AccessibilityOnboardingBridge: NSObject, NSWindowDelegate {

    @objc static let settingsURL: URL? = URL(string: "x-apple.systempreferences:com.apple.Settings.PrivacySecurity.extension?Privacy_Accessibility")

    @objc let window: NSWindow
    @objc var onPermissionGranted: (() -> Void)?
    private var pollTimer: Timer?

    @objc var isPolling: Bool {
        pollTimer != nil
    }

    @objc override init() {
        let hosting = NSHostingController(rootView: AccessibilityOnboardingView())
        hosting.sizingOptions = .preferredContentSize

        let window = NSWindow(contentViewController: hosting)
        window.title = "Zooom3 Setup"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        window.level = .floating
        self.window = window

        super.init()

        window.delegate = self

        hosting.rootView = AccessibilityOnboardingView(onOpenSettings: { [weak self] in
            self?.openSettings()
        })
    }

    @objc func showWindow() {
        window.makeKeyAndOrderFront(nil)
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc func closeWindow() {
        stopPolling()
        window.orderOut(nil)
    }

    @objc func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            if AXIsProcessTrusted() {
                self?.stopPolling()
                self?.onPermissionGranted?()
            }
        }
    }

    @objc func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func openSettings() {
        if let url = Self.settingsURL {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // Don't stop polling — permission may still be granted via System Settings
    }

    deinit {
        stopPolling()
    }
}
