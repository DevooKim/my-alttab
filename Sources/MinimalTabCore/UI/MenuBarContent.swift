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

    /// Open the SwiftUI `Settings` scene via the selector AppKit installs for
    /// it. Used by the macOS 13 menu fallback and by the in-switcher settings
    /// hotkey (which fires from the CGEventTap, where `SettingsLink` is
    /// unavailable). The selector was renamed across releases —
    /// `showSettingsWindow:` on macOS 13+, `showPreferencesWindow:` earlier —
    /// so try both and use whichever the responder chain accepts.
    static func openSettingsLegacy() {
        NSApp.activate(ignoringOtherApps: true)
        let selectors = ["showSettingsWindow:", "showPreferencesWindow:"]
        for name in selectors where NSApp.sendAction(Selector((name)), to: nil, from: nil) {
            return
        }
    }
}
