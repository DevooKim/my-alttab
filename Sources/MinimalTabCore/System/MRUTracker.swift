import AppKit
import ApplicationServices

/// Tracks windows in most-recently-used order. Two signals feed it:
/// app activation notifications (the activated app's focused window) and
/// explicit switcher commits. AXUIElement identity is stable for a given
/// window, so CFEqual matches across enumerations.
@MainActor
public final class MRUTracker {
    private var elements: [AXUIElement] = []
    private var observer: NSObjectProtocol?
    private let capacity = 100

    public init() {}

    public func touch(_ element: AXUIElement) {
        elements.removeAll { CFEqual($0, element) }
        elements.insert(element, at: 0)
        if elements.count > capacity {
            elements.removeLast(elements.count - capacity)
        }
    }

    public func rank(of element: AXUIElement?) -> Int? {
        guard let element else { return nil }
        return elements.firstIndex { CFEqual($0, element) }
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
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            var focused: CFTypeRef?
            guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focused) == .success,
                  let value = focused, CFGetTypeID(value) == AXUIElementGetTypeID() else {
                return
            }
            let window = unsafeDowncast(value as AnyObject, to: AXUIElement.self)
            MainActor.assumeIsolated {
                self?.touch(window)
            }
        }
    }

    public func stopObserving() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observer = nil
    }
}
