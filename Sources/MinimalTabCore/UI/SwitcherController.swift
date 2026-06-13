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

    /// True between begin() and the session materializing (background
    /// enumeration in flight). A monotonically-increasing token lets a
    /// cancel()/commit() that happens mid-load discard the stale result.
    private var isLoading = false
    private var loadToken = 0
    /// Triggers/commit that arrive before the window list finishes loading
    /// are recorded here and replayed once the session exists, so the
    /// hold-modifier interaction never drops a keystroke.
    private enum PendingAction { case advance, retreat, selectLast, commit }
    private var pendingActions: [PendingAction] = []

    /// The tap treats a loading session as active so it keeps swallowing
    /// trigger keyDowns and routing flagsChanged to us.
    public var isActive: Bool { session != nil || isLoading }

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
        if isLoading { pendingActions.append(.advance); return }
        begin(mode: mode)
    }

    /// Shift+trigger: move backward; from idle, open selecting the last item.
    public func handleReverseTrigger(mode: SwitcherMode) {
        if session != nil {
            session?.retreat()
            syncViewModel()
            return
        }
        if isLoading { pendingActions.append(.retreat); return }
        // Opening fresh in reverse: select the last item once it loads.
        begin(mode: mode, openingAction: .selectLast)
    }

    /// Single reverse key while the list is open: move backward one step.
    public func retreatSelection() {
        if isLoading { pendingActions.append(.retreat); return }
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
            // Released before the list finished loading: commit whatever
            // selection the queued actions resolve to once it arrives.
            if isLoading { pendingActions.append(.commit); return }
            commit()
        }
    }

    public func cancel() {
        guard session != nil || isLoading else { return }
        // Invalidate any in-flight load so its completion is discarded.
        isLoading = false
        loadToken &+= 1
        pendingActions.removeAll()
        emptyStateTimer?.invalidate()
        emptyStateTimer = nil
        session = nil
        activeShortcut = nil
        panel.hide()
    }

    /// Enumerate windows off the main thread (AX/CGS IPC is the dominant
    /// open-time cost), then materialize the session back on the main actor.
    /// The panel is shown only once the list is ready, so it sizes correctly
    /// in one pass — no resize jump. Trigger/commit keystrokes that arrive
    /// mid-load are queued in `pendingActions` and replayed on arrival.
    private func begin(mode: SwitcherMode, openingAction: PendingAction? = nil) {
        // Capture everything the enumeration needs on the main actor first:
        // Preferences and the MRU tracker are both @MainActor.
        let blacklist = preferences.blacklistedBundleIDs
        let showAllSpaces = preferences.showAllSpaces
        let includeMinimized = preferences.includeMinimized
        let rank = mru.rankSnapshot()
        let enumerator = self.enumerator

        switch mode {
        case .global: activeShortcut = preferences.globalShortcut
        case .sameApp: activeShortcut = preferences.sameAppShortcut
        }

        isLoading = true
        loadToken &+= 1
        let token = loadToken
        if let openingAction { pendingActions.append(openingAction) }

        Task.detached(priority: .userInitiated) {
            let mruRank: (WindowInfo) -> Int? = { rank($0.axElement) }
            let raw: [WindowInfo]
            switch mode {
            case .global:
                raw = enumerator.allWindows(
                    blacklist: blacklist, showAllSpaces: showAllSpaces, mruRank: mruRank
                )
            case .sameApp:
                raw = enumerator.frontmostAppWindows(blacklist: blacklist, mruRank: mruRank)
            }
            let windows = WindowInfo.visibleWindows(raw, includeMinimized: includeMinimized)
            await MainActor.run { [weak self] in
                self?.finishBegin(mode: mode, windows: windows, rawCount: raw.count, token: token)
            }
        }
    }

    /// Main-actor completion of a background enumeration. Drops stale loads
    /// (cancelled/superseded while in flight) via the token check.
    private func finishBegin(mode: SwitcherMode, windows: [WindowInfo], rawCount: Int, token: Int) {
        guard token == loadToken, isLoading else { return }
        isLoading = false
        NSLog("MinimalTab: trigger \(mode), \(rawCount) windows enumerated, \(windows.count) visible")
        var newSession = SwitcherSession(windows: windows)
        // Replay any triggers/commit that arrived while loading.
        let queued = pendingActions
        pendingActions.removeAll()
        var shouldCommit = false
        for action in queued {
            switch action {
            case .advance: newSession.advance()
            case .retreat: newSession.retreat()
            case .selectLast where windows.count > 1: newSession.select(index: windows.count - 1)
            case .selectLast: break
            case .commit: shouldCommit = true
            }
        }
        session = newSession
        syncViewModel()
        if shouldCommit { commit(); return }

        panel.show()
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
        isLoading = false
        pendingActions.removeAll()
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
