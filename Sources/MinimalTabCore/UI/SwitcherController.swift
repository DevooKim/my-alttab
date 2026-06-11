import AppKit

/// Owns the live switcher session. One instance for the app's lifetime.
@MainActor
public final class SwitcherController {
    private let enumerator = WindowEnumerator()
    private let activator = WindowActivator()
    private let preferences: Preferences
    private let viewModel = SwitcherViewModel()
    private lazy var panel = SwitcherPanel(model: viewModel)

    private var session: SwitcherSession?
    private var activeShortcut: KeyboardShortcut?

    public var isActive: Bool { session != nil }

    public init(preferences: Preferences = .shared) {
        self.preferences = preferences
        viewModel.onRowClicked = { [weak self] index in
            self?.session?.select(index: index)
            self?.commit()
        }
    }

    /// Called by HotKeyMonitor on every matching trigger keyDown.
    public func handleTrigger(mode: SwitcherMode) {
        if session != nil {
            session?.advance()
            syncViewModel()
            return
        }
        begin(mode: mode)
    }

    /// Called by HotKeyMonitor on flagsChanged during an active session.
    public func handleFlagsChanged(_ flags: CGEventFlags) {
        guard let shortcut = activeShortcut else { return }
        if !shortcut.modifiersStillHeld(flags: flags) {
            commit()
        }
    }

    public func cancel() {
        guard session != nil else { return }
        session = nil
        activeShortcut = nil
        panel.hide()
    }

    private func begin(mode: SwitcherMode) {
        let raw: [WindowInfo]
        switch mode {
        case .global:
            raw = enumerator.allWindows()
            activeShortcut = preferences.globalShortcut
        case .sameApp:
            raw = enumerator.frontmostAppWindows()
            activeShortcut = preferences.sameAppShortcut
        }
        let windows = WindowInfo.visibleWindows(raw, includeMinimized: preferences.includeMinimized)
        NSLog("MinimalTab: trigger \(mode), \(raw.count) windows enumerated, \(windows.count) visible")
        guard !windows.isEmpty else {
            activeShortcut = nil
            return
        }
        session = SwitcherSession(windows: windows)
        syncViewModel()
        panel.show()
    }

    private func commit() {
        let selected = session?.selectedWindow
        session = nil
        activeShortcut = nil
        panel.hide()
        if let selected {
            activator.activate(selected)
        }
    }

    private func syncViewModel() {
        guard let session else { return }
        viewModel.windows = session.windows
        viewModel.selectedIndex = session.selectedIndex
    }
}
