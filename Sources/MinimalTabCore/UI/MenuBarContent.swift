import SwiftUI
import AppKit

/// Contents of the `MenuBarExtra` (status-bar dropdown). Replaces the
/// hand-built `NSMenu` from the old `StatusBarController`.
public struct MenuBarContent: View {
    public init() {}

    public var body: some View {
        Button(L("menu.about")) { AboutPanel.present() }

        Divider()

        Button(L("menu.checkForUpdates")) { Updater.checkForUpdates(silent: false) }

        Divider()

        // ⌘, — the standard Settings shortcut. On macOS 14+ `SettingsLink`
        // opens the `Settings` scene directly; on macOS 13 it has no
        // equivalent, so fall back to the AppKit selector the scene installs.
        if #available(macOS 14, *) {
            SettingsLink { Text(L("menu.settings")) }
                .keyboardShortcut(",", modifiers: .command)
        } else {
            Button(L("menu.settings")) { Self.openSettingsLegacy() }
                .keyboardShortcut(",", modifiers: .command)
        }

        Divider()

        Button(L("menu.quit")) { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
    }

    /// Open the Settings scene from the macOS 13 menu fallback.
    static func openSettingsLegacy() {
        SettingsOpener.open()
    }
}

/// Opens the SwiftUI `Settings` scene from non-View contexts — the macOS 13
/// menu fallback and the in-switcher settings hotkey (which fires from the
/// CGEventTap). The `showSettingsWindow:` selector proved unreliable on
/// macOS 26 (it reports handled but no window appears), so route through the
/// `openSettings` environment action via a notification observed by an
/// always-mounted view in the scene graph (the MenuBarExtra label), mirroring
/// the onboarding-open mechanism.
@MainActor
public enum SettingsOpener {
    public static let openNotification = Notification.Name("MinimalTab.openSettings")

    public static func open() {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: openNotification, object: nil)
    }
}
