import AppKit

/// Coordination glue for the SwiftUI onboarding `Window` scene: the scene id,
/// the open notification (posted by `AppDelegate` on first run), and the finish
/// handler. Closing by id keeps macOS 13 working — `dismissWindow` is 14+.
@MainActor
public enum OnboardingWindow {
    public static let id = "onboarding"
    public static let openNotification = Notification.Name("MinimalTab.openOnboarding")

    /// Ask the SwiftUI layer to open the onboarding window. Safe to call from
    /// the app delegate, where `openWindow` is not available.
    ///
    /// `MenuBarExtra` content (which hosts the notification observer) mounts
    /// lazily, so a single post fired from `applicationDidFinishLaunching` can
    /// be dropped. Retry on a short timer until the window actually appears.
    public static func open() {
        NSApp.activate(ignoringOtherApps: true)
        var attempts = 0
        let timer = Timer(timeInterval: 0.1, repeats: true) { t in
            Task { @MainActor in
                attempts += 1
                if window() != nil || attempts > 30 {
                    t.invalidate()
                    return
                }
                NotificationCenter.default.post(name: openNotification, object: nil)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    /// Mark onboarding complete and close the window. Finds the window by the
    /// scene id in its frame autosave / identifier so it works on macOS 13
    /// (no `dismissWindow`).
    public static func finish() {
        Preferences.shared.hasCompletedOnboarding = true
        window()?.close()
    }

    /// The onboarding scene's NSWindow. SwiftUI tags `Window(id:)` scenes with
    /// the id in the window's `identifier`.
    private static func window() -> NSWindow? {
        NSApp.windows.first { $0.identifier?.rawValue == id }
    }
}
