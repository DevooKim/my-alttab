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

    // Settings key (single key while the list is open) defaults to comma
    expectEqual(prefs.settingsKey, 43, "settings key defaults to comma")
    prefs.settingsKey = 1 // S
    expectEqual(Preferences(defaults: defaults).settingsKey, 1, "settings key persists")

    // Reverse key defaults to left Shift and persists
    expectEqual(prefs.reverseKey, 56, "reverse key defaults to left shift")
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

    // Onboarding completion flag
    expect(!prefs.hasCompletedOnboarding, "onboarding defaults to not completed")
    prefs.hasCompletedOnboarding = true
    expect(Preferences(defaults: defaults).hasCompletedOnboarding, "onboarding completion persists")

    // UI appearance settings
    expectEqual(prefs.listSize, .medium, "list size defaults to medium")
    prefs.listSize = .large
    expectEqual(Preferences(defaults: defaults).listSize, .large, "list size persists")

    expectEqual(prefs.highlightStyle, .fill, "highlight style defaults to fill")
    prefs.highlightStyle = .border
    expectEqual(Preferences(defaults: defaults).highlightStyle, .border, "highlight style persists")

    defaults.set("garbage", forKey: Preferences.Key.listSize)
    expectEqual(prefs.listSize, .medium, "corrupt list size falls back to medium")

    // Sizes scale monotonically
    expect(ListSize.small.panelWidth < ListSize.medium.panelWidth
           && ListSize.medium.panelWidth < ListSize.large.panelWidth,
           "panel width grows with size")
    expect(ListSize.small.fontSize < ListSize.large.fontSize, "font grows with size")

    defaults.removePersistentDomain(forName: suite)
}
