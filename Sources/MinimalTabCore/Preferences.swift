import Foundation

/// Settings store. Key strings are shared with SwiftUI @AppStorage in
/// SettingsView, so both sides read/write the same UserDefaults entries.
public final class Preferences {
    public enum Key {
        public static let includeMinimized = "includeMinimized"
        public static let globalShortcut = "globalShortcut"
        public static let sameAppShortcut = "sameAppShortcut"
    }

    public static let shared = Preferences()

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Key.includeMinimized: true])
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

    private func readShortcut(_ key: String) -> KeyboardShortcut? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(KeyboardShortcut.self, from: data)
    }

    private func writeShortcut(_ shortcut: KeyboardShortcut, key: String) {
        defaults.set(try? JSONEncoder().encode(shortcut), forKey: key)
    }
}
