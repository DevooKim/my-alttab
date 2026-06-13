import AppKit
import ApplicationServices

/// One switchable window. `axElement` is optional so pure-logic tests can
/// construct instances without touching the Accessibility API.
public struct WindowInfo: Identifiable, Equatable {
    public let id: UUID
    public let pid: pid_t
    public let appName: String
    public let appIcon: NSImage?
    public let title: String
    public let isMinimized: Bool
    /// True when the owning app is hidden (Cmd+H).
    public let isHidden: Bool
    /// 1-based Space (desktop) ordinal across all displays; nil when the
    /// window's Space couldn't be determined (e.g. minimized/off-screen).
    public let spaceNumber: Int?
    /// CGWindowID, used to activate windows on inactive Spaces that have no
    /// reachable AX element. 0 when unknown.
    public let windowID: CGWindowID
    public let axElement: AXUIElement?

    public init(
        id: UUID,
        pid: pid_t,
        appName: String,
        appIcon: NSImage?,
        title: String,
        isMinimized: Bool,
        isHidden: Bool,
        spaceNumber: Int? = nil,
        windowID: CGWindowID = 0,
        axElement: AXUIElement?
    ) {
        self.id = id
        self.pid = pid
        self.appName = appName
        self.appIcon = appIcon
        self.title = title
        self.isMinimized = isMinimized
        self.isHidden = isHidden
        self.spaceNumber = spaceNumber
        self.windowID = windowID
        self.axElement = axElement
    }

    /// Display title with fallback + minimized suffix. The strings are
    /// injected so this stays pure (Models has no system/localization
    /// dependency); the View passes localized values. Defaults keep the
    /// model usable in tests and as a sensible fallback.
    public func displayTitle(untitled: String = "Untitled", minimizedSuffix: String = " (minimized)") -> String {
        let base = title.isEmpty ? untitled : title
        return isMinimized ? base + minimizedSuffix : base
    }

    /// Convenience for tests and non-localized callers.
    public var displayTitle: String { displayTitle() }

    /// PRD 4.A: with the setting OFF, minimized/hidden windows are removed
    /// from the list entirely.
    public static func visibleWindows(_ all: [WindowInfo], includeMinimized: Bool) -> [WindowInfo] {
        includeMinimized ? all : all.filter { !$0.isMinimized && !$0.isHidden }
    }

    public static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.id == rhs.id
    }
}
