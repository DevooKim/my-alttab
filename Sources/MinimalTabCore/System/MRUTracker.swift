import AppKit
import ApplicationServices

/// Tracks windows in most-recently-used order. Two signals feed it:
/// app activation notifications (the activated app's focused window) and
/// explicit switcher commits.
///
/// Identity is the `CGWindowID`, NOT the AXUIElement. An AXUIElement is only
/// reachable for windows on the *active* Space, so AX-based identity broke MRU
/// the moment a window on another Space was involved (its element is nil, so it
/// could never match). CGWindowID is stable for a window's lifetime and Space-
/// independent, so MRU now survives switching across Spaces.
@MainActor
public final class MRUTracker {
    /// Where a touch came from. A switcher commit is authoritative about which
    /// window the user chose; the activation notification that fires right
    /// after it can name a *different* window of the same app (the app's last
    /// focused window), which would otherwise clobber the chosen one at the
    /// front of the list.
    public enum Source { case commit, activation }

    private var windowIDs: [CGWindowID] = []
    private var observer: NSObjectProtocol?
    private let capacity = 100

    /// The window a switcher commit just selected, and until when activation
    /// touches should defer to it. Within this window, an activation touch for
    /// a *different* window is ignored so the commit stays at the front.
    private var committedID: CGWindowID = 0
    private var committedUntil: Date = .distantPast
    private let commitGuard: TimeInterval = 1.0

    public init() {}

    public func touch(_ windowID: CGWindowID, source: Source = .commit) {
        guard windowID != 0 else { return }

        if source == .commit {
            committedID = windowID
            committedUntil = Date().addingTimeInterval(commitGuard)
        } else {
            // Activation right after a commit often names the app's previously
            // focused window, not the one the user just picked. Ignore it while
            // the guard is live unless it actually matches the committed window.
            if Date() < committedUntil, windowID != committedID {
                return
            }
        }

        windowIDs.removeAll { $0 == windowID }
        windowIDs.insert(windowID, at: 0)
        if windowIDs.count > capacity {
            windowIDs.removeLast(windowIDs.count - capacity)
        }
    }

    public func rank(of windowID: CGWindowID) -> Int? {
        guard windowID != 0 else { return nil }
        return windowIDs.firstIndex(of: windowID)
    }

    /// An immutable snapshot of the current MRU order, safe to use for
    /// ranking from a background thread (enumeration runs off-main, but the
    /// tracker is @MainActor).
    public func rankSnapshot() -> @Sendable (CGWindowID) -> Int? {
        let snapshot = windowIDs
        return { windowID in
            guard windowID != 0 else { return nil }
            return snapshot.firstIndex(of: windowID)
        }
    }

    /// Records the focused window of whichever app the user activates, so
    /// ordinary clicking around (not just switcher use) builds MRU history.
    public func startObservingActivations() {
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            MainActor.assumeIsolated {
                self?.touchFocusedWindow(of: app, retriesLeft: 4)
            }
        }
    }

    /// A freshly launched app activates before its first window exists, so
    /// the AX lookup fails at notification time and the window would never
    /// enter MRU history. Retry briefly while the app stays frontmost.
    private func touchFocusedWindow(of app: NSRunningApplication, retriesLeft: Int) {
        if let wid = Self.focusedWindowID(of: app.processIdentifier) {
            touch(wid, source: .activation)
            return
        }
        guard retriesLeft > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            MainActor.assumeIsolated {
                guard NSWorkspace.shared.frontmostApplication?.processIdentifier
                        == app.processIdentifier else { return }
                self?.touchFocusedWindow(of: app, retriesLeft: retriesLeft - 1)
            }
        }
    }

    /// CGWindowID of the app's focused window, or nil (no window yet, app
    /// unresponsive, or the window is on another Space).
    public static func focusedWindowID(of pid: pid_t) -> CGWindowID? {
        let axApp = AXUIElementCreateApplication(pid)
        // Don't let a hung app stall the main thread for the default ~6s.
        AXUIElementSetMessagingTimeout(axApp, 0.25)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focused) == .success,
              let value = focused, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        let window = unsafeDowncast(value as AnyObject, to: AXUIElement.self)
        return SpaceTracker.windowID(for: window)
    }

    public func stopObserving() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observer = nil
    }
}
