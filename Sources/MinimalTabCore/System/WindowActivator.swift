import AppKit
import ApplicationServices

public struct WindowActivator {
    public init() {}

    /// Brings the window to the front, restoring it first if minimized or
    /// if its app is hidden (PRD 4.A).
    ///
    /// `skipSpaceAnimation` (experimental) tries to jump to the window's Space
    /// without the slide animation before focusing it; it's best-effort and
    /// falls back to the normal animated path on failure.
    public func activate(_ window: WindowInfo, skipSpaceAnimation: Bool = false) {
        if skipSpaceAnimation, window.windowID != 0 {
            // Best-effort: snap to the window's Space without animation. If it
            // returns false, fall through to the normal (animated) activation.
            _ = SpaceSwitcher.jumpToSpace(ofWindowID: window.windowID)
        }
        guard let axElement = window.axElement else {
            // Window on an inactive Space has no reachable AX element.
            // Activating the app and raising by CGWindowID makes macOS
            // switch to that Space and focus the window.
            activateByWindowID(window)
            return
        }
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

    /// Activates a window identified only by CGWindowID (its AX element
    /// wasn't reachable because it lives on an inactive Space). Re-fetches
    /// the app's AX windows after activating — once macOS switches Spaces,
    /// the target window becomes AX-visible and can be raised/focused.
    private func activateByWindowID(_ window: WindowInfo) {
        guard let app = NSRunningApplication(processIdentifier: window.pid) else { return }
        app.unhide()
        app.activate(options: [.activateIgnoringOtherApps])

        // After activation the Space switch is async; retry briefly to find
        // and raise the specific window by its CGWindowID.
        let axApp = AXUIElementCreateApplication(window.pid)
        AXUIElementSetMessagingTimeout(axApp, 0.25)
        func raiseMatching() -> Bool {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
                  let axWindows = value as? [AXUIElement] else { return false }
            for axWindow in axWindows where SpaceTracker.windowID(for: axWindow) == window.windowID {
                AXUIElementSetAttributeValue(axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
                AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
                return true
            }
            return false
        }
        if raiseMatching() { return }
        // The Space switch is async, so the target window often isn't AX-visible
        // yet right after activate() — the app's window list can even come back
        // empty. Retry a few times over ~1s until the specific window appears,
        // instead of a single 0.15s attempt (which raised whatever window the
        // app surfaced by default — frequently the wrong one).
        retryRaise(raiseMatching, attemptsLeft: 10, interval: 0.1)
    }

    /// Polls `attempt` until it succeeds or the attempts run out. Used to wait
    /// out the async Space switch before raising a specific off-Space window.
    private func retryRaise(_ attempt: @escaping () -> Bool, attemptsLeft: Int, interval: TimeInterval) {
        guard attemptsLeft > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            if attempt() { return }
            self.retryRaise(attempt, attemptsLeft: attemptsLeft - 1, interval: interval)
        }
    }

    /// Quick Action: presses the window's close button (same as clicking
    /// the red traffic light — the app may show a save dialog).
    public func close(_ window: WindowInfo) {
        guard let axElement = window.axElement else { return }
        var button: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axElement, kAXCloseButtonAttribute as CFString, &button) == .success,
              let value = button, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return
        }
        let closeButton = unsafeDowncast(value as AnyObject, to: AXUIElement.self)
        AXUIElementPerformAction(closeButton, kAXPressAction as CFString)
    }

    /// Quick Action: asks the app to quit normally (it may prompt to save).
    public func quitApp(pid: pid_t) {
        NSRunningApplication(processIdentifier: pid)?.terminate()
    }
}
