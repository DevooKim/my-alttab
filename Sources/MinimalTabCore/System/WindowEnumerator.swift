import AppKit
import ApplicationServices

/// Lists switchable windows via the Accessibility API.
///
/// IMPORTANT: window titles deliberately come from kAXTitleAttribute, NOT
/// kCGWindowName — the latter is redacted unless the app holds Screen
/// Recording permission, which this app must never request (PRD 2.B).
public struct WindowEnumerator {
    public init() {}

    /// All windows of all regular apps, most-recently-used first
    /// (z-order fallback for windows never tracked), minimized last.
    /// Apps in `blacklist` (bundle IDs) are skipped entirely.
    public func allWindows(
        blacklist: [String] = [],
        mruRank: (WindowInfo) -> Int? = { _ in nil }
    ) -> [WindowInfo] {
        var windows: [WindowInfo] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            if Self.isExcluded(app.bundleIdentifier, blacklist: blacklist) { continue }
            windows.append(contentsOf: windowsOf(app: app))
        }
        // Include our own windows (e.g. the open settings window) — this
        // app is .accessory, so the loop above skips it. The switcher
        // panel itself is borderless and fails the standard-window subrole
        // check, so only real windows like Settings appear.
        let own = NSRunningApplication.current
        if !Self.isExcluded(own.bundleIdentifier, blacklist: blacklist) {
            windows.append(contentsOf: windowsOf(app: own))
        }
        return Self.order(windows, pidRank: Self.currentPidRank(), mruRank: mruRank)
    }

    /// Windows of the frontmost app only (Same-App Switch, PRD 2.C).
    public func frontmostAppWindows(
        blacklist: [String] = [],
        mruRank: (WindowInfo) -> Int? = { _ in nil }
    ) -> [WindowInfo] {
        guard let app = NSWorkspace.shared.frontmostApplication,
              !Self.isExcluded(app.bundleIdentifier, blacklist: blacklist) else {
            return []
        }
        return Self.order(windowsOf(app: app), pidRank: Self.currentPidRank(), mruRank: mruRank)
    }

    private func windowsOf(app: NSRunningApplication) -> [WindowInfo] {
        let pid = app.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)
        // An unresponsive app must not stall the whole list: the default
        // AX messaging timeout is ~6 seconds, so cap it per app.
        AXUIElementSetMessagingTimeout(axApp, 0.25)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
              let axWindows = value as? [AXUIElement] else {
            return []
        }

        let appName = app.localizedName ?? "Unknown"
        return axWindows.compactMap { axWindow in
            // Only standard windows — skips palettes, sheets, popovers.
            guard stringAttribute(axWindow, kAXSubroleAttribute) == kAXStandardWindowSubrole as String else {
                return nil
            }
            return WindowInfo(
                id: UUID(),
                pid: pid,
                appName: appName,
                appIcon: app.icon,
                title: stringAttribute(axWindow, kAXTitleAttribute) ?? "",
                isMinimized: boolAttribute(axWindow, kAXMinimizedAttribute),
                isHidden: app.isHidden,
                axElement: axWindow
            )
        }
    }

    private func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private func boolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return false
        }
        return (value as? Bool) ?? false
    }

    /// Blacklist matching: exact bundle ID, or prefix when the entry ends
    /// with "." (AltTab convention, e.g. "com.parallels." matches every
    /// Parallels app).
    public static func isExcluded(_ bundleID: String?, blacklist: [String]) -> Bool {
        guard let bundleID else { return false }
        return blacklist.contains { entry in
            entry.hasSuffix(".") ? bundleID.hasPrefix(entry) : bundleID == entry
        }
    }

    /// Front-to-back rank per PID from the on-screen window list. Reads
    /// only PIDs/order — no window names — so no extra permission needed.
    public static func currentPidRank() -> [pid_t: Int] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else {
            return [:]
        }
        var rank: [pid_t: Int] = [:]
        var next = 0
        for entry in list {
            guard let layer = entry[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = entry[kCGWindowOwnerPID as String] as? pid_t else { continue }
            if rank[pid] == nil {
                rank[pid] = next
                next += 1
            }
        }
        return rank
    }

    /// Pure, unit-tested ordering. Priority: minimized last, then MRU rank
    /// (most recently used first), then z-order (unranked apps last, e.g.
    /// hidden apps with no on-screen windows), AX order kept within an app.
    public static func order(
        _ windows: [WindowInfo],
        pidRank: [pid_t: Int],
        mruRank: (WindowInfo) -> Int? = { _ in nil }
    ) -> [WindowInfo] {
        let sorted = windows.enumerated().sorted { a, b in
            let keyA = (a.element.isMinimized ? 1 : 0, mruRank(a.element) ?? Int.max,
                        pidRank[a.element.pid] ?? Int.max, a.offset)
            let keyB = (b.element.isMinimized ? 1 : 0, mruRank(b.element) ?? Int.max,
                        pidRank[b.element.pid] ?? Int.max, b.offset)
            return keyA < keyB
        }
        return sorted.map(\.element)
    }

    /// Backward-compatible alias: pure z-order without MRU input.
    public static func sortByZOrder(_ windows: [WindowInfo], pidRank: [pid_t: Int]) -> [WindowInfo] {
        order(windows, pidRank: pidRank)
    }
}
