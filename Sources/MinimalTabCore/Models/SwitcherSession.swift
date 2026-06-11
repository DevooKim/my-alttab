import Foundation

/// Pure selection state for one switcher invocation (modifier held down).
/// Created when the trigger first fires, discarded on commit/cancel.
public struct SwitcherSession {
    public private(set) var windows: [WindowInfo]
    public private(set) var selectedIndex: Int

    public init(windows: [WindowInfo]) {
        self.windows = windows
        // Index 0 is the frontmost (current) window, so the first trigger
        // press should land on the next one — standard Alt-Tab behavior.
        self.selectedIndex = windows.count > 1 ? 1 : 0
    }

    public var selectedWindow: WindowInfo? {
        windows.indices.contains(selectedIndex) ? windows[selectedIndex] : nil
    }

    public mutating func advance() {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % windows.count
    }

    public mutating func retreat() {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + windows.count) % windows.count
    }

    public mutating func select(index: Int) {
        guard windows.indices.contains(index) else { return }
        selectedIndex = index
    }

    /// Quick Action (close): drops the selected window from the list and
    /// keeps the selection on the next item (clamped to the end).
    @discardableResult
    public mutating func removeSelected() -> WindowInfo? {
        guard let removed = selectedWindow else { return nil }
        windows.remove(at: selectedIndex)
        selectedIndex = min(selectedIndex, max(0, windows.count - 1))
        return removed
    }

    /// Quick Action (quit app): drops every window belonging to the app.
    public mutating func removeWindows(pid: pid_t) {
        windows.removeAll { $0.pid == pid }
        selectedIndex = min(selectedIndex, max(0, windows.count - 1))
    }
}
