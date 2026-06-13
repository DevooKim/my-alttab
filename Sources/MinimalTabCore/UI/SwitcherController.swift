import AppKit

/// Owns the live switcher session. One instance for the app's lifetime.
@MainActor
public final class SwitcherController {
    private let enumerator = WindowEnumerator()
    private let activator = WindowActivator()
    private let preferences: Preferences
    private let viewModel = SwitcherViewModel()
    private let mru = MRUTracker()
    private lazy var panel = SwitcherPanel(model: viewModel)

    private var session: SwitcherSession?
    private var activeShortcut: KeyboardShortcut?
    /// Auto-dismiss timer for the "no windows" empty state.
    private var emptyStateTimer: Timer?

    public var isActive: Bool { session != nil }

    public init(preferences: Preferences = .shared) {
        self.preferences = preferences
        mru.startObservingActivations()
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

    /// Shift+trigger: move backward; from idle, open selecting the last item.
    public func handleReverseTrigger(mode: SwitcherMode) {
        if session != nil {
            session?.retreat()
            syncViewModel()
            return
        }
        begin(mode: mode)
        if let count = session?.windows.count, count > 1 {
            session?.select(index: count - 1)
            syncViewModel()
        }
    }

    /// Single reverse key while the list is open: move backward one step.
    public func retreatSelection() {
        guard session != nil else { return }
        session?.retreat()
        syncViewModel()
    }

    /// Quick Action: close the selected window without leaving the list.
    public func quickCloseSelected() {
        guard let selected = session?.selectedWindow else { return }
        activator.close(selected)
        session?.removeSelected()
        endSessionIfEmptyOrSync()
    }

    /// Quick Action: quit the selected window's app without leaving the list.
    public func quickQuitSelected() {
        guard let selected = session?.selectedWindow else { return }
        activator.quitApp(pid: selected.pid)
        session?.removeWindows(pid: selected.pid)
        endSessionIfEmptyOrSync()
    }

    private func endSessionIfEmptyOrSync() {
        if session?.windows.isEmpty ?? true {
            cancel()
        } else {
            syncViewModel()
        }
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
        emptyStateTimer?.invalidate()
        emptyStateTimer = nil
        session = nil
        activeShortcut = nil
        panel.hide()
    }

    private func begin(mode: SwitcherMode) {
        let raw: [WindowInfo]
        let rank: (WindowInfo) -> Int? = { [mru] in mru.rank(of: $0.axElement) }
        switch mode {
        case .global:
            raw = enumerator.allWindows(
                blacklist: preferences.blacklistedBundleIDs,
                showAllSpaces: preferences.showAllSpaces,
                mruRank: rank
            )
            activeShortcut = preferences.globalShortcut
        case .sameApp:
            raw = enumerator.frontmostAppWindows(blacklist: preferences.blacklistedBundleIDs, mruRank: rank)
            activeShortcut = preferences.sameAppShortcut
        }
        let windows = WindowInfo.visibleWindows(raw, includeMinimized: preferences.includeMinimized)
        NSLog("MinimalTab: trigger \(mode), \(raw.count) windows enumerated, \(windows.count) visible")
        session = SwitcherSession(windows: windows)
        syncViewModel()
        panel.show()
        // Empty state: nothing to commit, so auto-dismiss after a moment
        // (modifier release / Escape also close it, whichever comes first).
        emptyStateTimer?.invalidate()
        if windows.isEmpty {
            let timer = Timer(timeInterval: 2.0, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.cancel() }
            }
            RunLoop.main.add(timer, forMode: .common)
            emptyStateTimer = timer
        }
    }

    private func commit() {
        emptyStateTimer?.invalidate()
        emptyStateTimer = nil
        let selected = session?.selectedWindow
        session = nil
        activeShortcut = nil
        panel.hide()
        if let selected {
            activator.activate(selected)
            if let axElement = selected.axElement {
                mru.touch(axElement)
            }
        }
    }

    private func syncViewModel() {
        guard let session else { return }
        viewModel.windows = session.windows
        viewModel.selectedIndex = session.selectedIndex
    }
}
