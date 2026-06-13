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
        self.axElement = axElement
    }

    /// PRD 4.B: empty titles fall back to "Untitled".
    /// PRD 4.A: minimized windows are suffixed with "(최소화됨)".
    public var displayTitle: String {
        let base = title.isEmpty ? "Untitled" : title
        return isMinimized ? base + " (최소화됨)" : base
    }

    /// PRD 4.A: with the setting OFF, minimized/hidden windows are removed
    /// from the list entirely.
    public static func visibleWindows(_ all: [WindowInfo], includeMinimized: Bool) -> [WindowInfo] {
        includeMinimized ? all : all.filter { !$0.isMinimized && !$0.isHidden }
    }

    public static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.id == rhs.id
    }
}
