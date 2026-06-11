import AppKit
import ApplicationServices

public struct WindowActivator {
    public init() {}

    /// Brings the window to the front, restoring it first if minimized or
    /// if its app is hidden (PRD 4.A).
    public func activate(_ window: WindowInfo) {
        guard let axElement = window.axElement else { return }
        let app = NSRunningApplication(processIdentifier: window.pid)

        if window.isMinimized {
            AXUIElementSetAttributeValue(axElement, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        if let app, app.isHidden {
            app.unhide()
        }

        // Raise the specific window, then focus its app. Order matters:
        // raising first makes this window the app's frontmost, so app
        // activation focuses it rather than another window.
        AXUIElementSetAttributeValue(axElement, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(axElement, kAXRaiseAction as CFString)
        app?.activate(options: [.activateIgnoringOtherApps])
    }
}
