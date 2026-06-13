import Foundation

/// Settings store. Key strings are shared with SwiftUI @AppStorage in
/// SettingsView, so both sides read/write the same UserDefaults entries.
public final class Preferences {
    public enum Key {
        public static let includeMinimized = "includeMinimized"
        public static let globalShortcut = "globalShortcut"
        public static let sameAppShortcut = "sameAppShortcut"
        public static let settingsKey = "settingsKey"
        public static let reverseKey = "reverseKey"
        public static let quickCloseKey = "quickCloseKey"
        public static let quickQuitKey = "quickQuitKey"
        public static let blacklistedBundleIDs = "blacklistedBundleIDs"
        public static let listSize = "listSize"
        public static let highlightStyle = "highlightStyle"
        public static let showAllSpaces = "showAllSpaces"
        public static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    public static let shared = Preferences()

    private let defaults: UserDefaults

    /// Default exclusions, adopted from AltTab (lwouis/alt-tab-macos):
    /// remote-desktop/VM viewers and background hosts whose windows are
    /// noise in a switcher. Entries ending in "." match by prefix.
    public static let defaultBlacklist: [String] = [
        "com.McAfee.McAfeeSafariHost",
        "com.apple.ScreenSharing",
        "com.microsoft.rdc.macos",
        "com.teamviewer.TeamViewer",
        "org.virtualbox.app.VirtualBoxVM",
        "com.parallels.",
        "com.citrix.XenAppViewer",
        "com.citrix.receiver.icaviewer.mac",
        "com.nicesoftware.dcvviewer",
        "com.vmware.fusion",
        "com.utmapp.UTM",
    ]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.includeMinimized: true,
            Key.blacklistedBundleIDs: Self.defaultBlacklist,
        ])
    }

    public var includeMinimized: Bool {
        get { defaults.bool(forKey: Key.includeMinimized) }
        set { defaults.set(newValue, forKey: Key.includeMinimized) }
    }

    public var globalShortcut: KeyboardShortcut {
        get { readShortcut(Key.globalShortcut) ?? .globalDefault }
        set { writeShortcut(newValue, key: Key.globalShortcut) }
    }

    public var sameAppShortcut: KeyboardShortcut {
        get { readShortcut(Key.sameAppShortcut) ?? .sameAppDefault }
        set { writeShortcut(newValue, key: Key.sameAppShortcut) }
    }

    /// Opens the settings window while the list is open. Default , (43).
    public var settingsKey: UInt16 {
        get { (defaults.object(forKey: Key.settingsKey) as? Int).map(UInt16.init) ?? 43 }
        set { defaults.set(Int(newValue), forKey: Key.settingsKey) }
    }

    /// Moves the selection backward while the list is open.
    /// Default ⇧ left Shift (keycode 56) — a modifier held alongside the
    /// trigger, handled via flagsChanged (see HotKeyMonitor).
    public var reverseKey: UInt16 {
        get { (defaults.object(forKey: Key.reverseKey) as? Int).map(UInt16.init) ?? 56 }
        set { defaults.set(Int(newValue), forKey: Key.reverseKey) }
    }

    /// Quick Action: close the selected window. Default W (keycode 13).
    public var quickCloseKey: UInt16 {
        get { (defaults.object(forKey: Key.quickCloseKey) as? Int).map(UInt16.init) ?? 13 }
        set { defaults.set(Int(newValue), forKey: Key.quickCloseKey) }
    }

    /// Quick Action: quit the selected window's app. Default Q (keycode 12).
    public var quickQuitKey: UInt16 {
        get { (defaults.object(forKey: Key.quickQuitKey) as? Int).map(UInt16.init) ?? 12 }
        set { defaults.set(Int(newValue), forKey: Key.quickQuitKey) }
    }

    /// Switcher list size (UI tab). Stored as the enum's raw string so
    /// SwiftUI @AppStorage can bind to the same key.
    public var listSize: ListSize {
        get { defaults.string(forKey: Key.listSize).flatMap(ListSize.init(rawValue:)) ?? .medium }
        set { defaults.set(newValue.rawValue, forKey: Key.listSize) }
    }

    /// Selected-row highlight style (UI tab).
    public var highlightStyle: HighlightStyle {
        get { defaults.string(forKey: Key.highlightStyle).flatMap(HighlightStyle.init(rawValue:)) ?? .fill }
        set { defaults.set(newValue.rawValue, forKey: Key.highlightStyle) }
    }

    /// True once the user has dismissed the first-run onboarding window.
    public var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Key.hasCompletedOnboarding) }
    }

    /// Show windows from every Space, not just the active one. OFF by
    /// default — when ON, titles of windows on inactive Spaces require
    /// Screen Recording permission (read via kCGWindowName). With this OFF
    /// the app never touches kCGWindowName.
    public var showAllSpaces: Bool {
        get { defaults.bool(forKey: Key.showAllSpaces) }
        set { defaults.set(newValue, forKey: Key.showAllSpaces) }
    }

    /// Apps whose windows never appear in the switcher.
    public var blacklistedBundleIDs: [String] {
        get { defaults.stringArray(forKey: Key.blacklistedBundleIDs) ?? [] }
        set { defaults.set(newValue, forKey: Key.blacklistedBundleIDs) }
    }

    private func readShortcut(_ key: String) -> KeyboardShortcut? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(KeyboardShortcut.self, from: data)
    }

    private func writeShortcut(_ shortcut: KeyboardShortcut, key: String) {
        defaults.set(try? JSONEncoder().encode(shortcut), forKey: key)
    }
}
