import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?
    private var settingsWindow: SettingsWindowController?
    private var switcher: SwitcherController?
    private var hotKeys: HotKeyMonitor?
    private var permissionRetryTimer: Timer?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("MinimalTab: launched, accessibility trusted=\(AccessibilityPermission.isGranted)")
        // PRD 3.A: menu-bar-only app, no Dock icon. (LSUIElement in
        // Info.plist covers the bundled app; this covers `swift run`.)
        NSApp.setActivationPolicy(.accessory)

        let settings = SettingsWindowController()
        settingsWindow = settings
        statusBar = StatusBarController(onSettings: { settings.show() })

        // PRD 4.D: check permission on launch, deep-link to System Settings.
        AccessibilityPermission.promptIfNeeded()

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
            settings.show()
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
    }

    public func applicationWillTerminate(_ notification: Notification) {
        hotKeys?.stop()
    }
}
