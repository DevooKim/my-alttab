import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var switcher: SwitcherController?
    private var hotKeys: HotKeyMonitor?
    private var permissionRetryTimer: Timer?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("MinimalTab: launched, accessibility trusted=\(AccessibilityPermission.isGranted)")
        // PRD 3.A: menu-bar-only app, no Dock icon. (LSUIElement in
        // Info.plist covers the bundled app; this covers `swift run`.)
        NSApp.setActivationPolicy(.accessory)

        // An accessory app has no main menu, but key equivalents (Cmd+W,
        // Cmd+Q, copy/paste in text fields) are dispatched through it —
        // install an invisible minimal one so they work in our windows.
        NSApp.mainMenu = Self.makeMainMenu()

        // The status bar (MenuBarExtra) and settings (Settings scene) are now
        // owned by the SwiftUI Scene graph in MinimalTabApp.

        // First run: show onboarding (which handles the permission prompt
        // inline). Later runs: the usual alert if permission is missing.
        if Preferences.shared.hasCompletedOnboarding {
            AccessibilityPermission.promptIfNeeded()
        } else {
            // Open the SwiftUI onboarding Window scene. The window posts back
            // through OnboardingWindow.finish() to set hasCompletedOnboarding
            // and close itself.
            OnboardingWindow.open()
        }

        let switcher = SwitcherController()
        self.switcher = switcher

        let hotKeys = HotKeyMonitor()
        hotKeys.isSessionActive = { Thread.isMainThread ? switcher.isActive : false }
        hotKeys.onTrigger = { mode in switcher.handleTrigger(mode: mode) }
        hotKeys.onReverseTrigger = { mode in switcher.handleReverseTrigger(mode: mode) }
        hotKeys.onReverseKey = { switcher.retreatSelection() }
        hotKeys.onFlagsChanged = { flags in switcher.handleFlagsChanged(flags) }
        hotKeys.onCancel = { switcher.cancel() }
        hotKeys.onQuickClose = { switcher.quickCloseSelected() }
        hotKeys.onOpenSettings = {
            switcher.cancel()
            MenuBarContent.openSettingsLegacy()
        }
        hotKeys.onQuickQuit = { switcher.quickQuitSelected() }
        if !hotKeys.start() {
            // Launched before the permission grant: retry until it lands,
            // so the user doesn't have to restart the app.
            permissionRetryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
                guard AccessibilityPermission.isGranted else { return }
                timer.invalidate()
                DispatchQueue.main.async { [weak self] in
                    if self?.hotKeys?.start() == true {
                        NSLog("MinimalTab: event tap started after late permission grant")
                    }
                }
            }
        }
        self.hotKeys = hotKeys

        // Check for updates shortly after launch, then every 24h while
        // running (silent: alert only when an update is available).
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            Updater.startAutomaticChecks()
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        hotKeys?.stop()
    }

    private static func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit My AltTab",
                                   action: #selector(NSApplication.terminate(_:)),
                                   keyEquivalent: "q"))
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = editMenu
        main.addItem(editItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        windowMenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        windowItem.submenu = windowMenu
        main.addItem(windowItem)

        return main
    }
}
