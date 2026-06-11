import Foundation
import CoreGraphics
import MinimalTabCore

func runPreferencesTests() {
    let suite = "test.minimaltab"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)

    let prefs = Preferences(defaults: defaults)
    expect(prefs.includeMinimized, "includeMinimized defaults to true")

    prefs.includeMinimized = false
    expect(!Preferences(defaults: defaults).includeMinimized, "includeMinimized persists")

    expectEqual(prefs.globalShortcut, .globalDefault, "global shortcut defaults to Option+Tab")
    expectEqual(prefs.sameAppShortcut, .sameAppDefault, "same-app shortcut defaults to Option+`")

    let custom = KeyboardShortcut(keyCode: 49, modifiers: CGEventFlags.maskControl.rawValue)
    prefs.globalShortcut = custom
    expectEqual(Preferences(defaults: defaults).globalShortcut, custom, "shortcut round-trips")

    defaults.set(Data([0x00, 0x01]), forKey: Preferences.Key.globalShortcut)
    expectEqual(prefs.globalShortcut, .globalDefault, "corrupt shortcut data falls back to default")

    defaults.removePersistentDomain(forName: suite)
}
