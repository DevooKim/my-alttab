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

    // Quick Action keys default to W (close) and Q (quit) and persist
    expectEqual(prefs.quickCloseKey, 13, "quick close defaults to W")
    expectEqual(prefs.quickQuitKey, 12, "quick quit defaults to Q")
    prefs.quickCloseKey = 7 // X
    expectEqual(Preferences(defaults: defaults).quickCloseKey, 7, "quick close key persists")

    // Settings shortcut defaults to Option+Comma and persists
    expectEqual(prefs.settingsShortcut, .settingsDefault, "settings shortcut defaults to Option+,")
    let customSettings = KeyboardShortcut(keyCode: 47, modifiers: CGEventFlags.maskCommand.rawValue)
    prefs.settingsShortcut = customSettings
    expectEqual(Preferences(defaults: defaults).settingsShortcut, customSettings,
                "settings shortcut persists")

    // Reverse key defaults to left arrow and persists
    expectEqual(prefs.reverseKey, 123, "reverse key defaults to left arrow")
    prefs.reverseKey = 126 // up arrow
    expectEqual(Preferences(defaults: defaults).reverseKey, 126, "reverse key persists")

    // Blacklist defaults to AltTab's exclusion list and persists overrides
    expectEqual(prefs.blacklistedBundleIDs, Preferences.defaultBlacklist,
                "blacklist defaults to AltTab exclusions")
    expect(Preferences.defaultBlacklist.contains("com.McAfee.McAfeeSafariHost"),
           "default blacklist includes McAfee host")
    expect(Preferences.defaultBlacklist.contains("com.parallels."),
           "default blacklist includes Parallels prefix")
    prefs.blacklistedBundleIDs = ["com.example.noisy"]
    expectEqual(Preferences(defaults: defaults).blacklistedBundleIDs, ["com.example.noisy"],
                "blacklist persists")

    defaults.removePersistentDomain(forName: suite)
}
