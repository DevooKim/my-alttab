import Foundation
import MinimalTabCore

private func makeWindow(
    title: String = "Doc",
    isMinimized: Bool = false,
    isHidden: Bool = false,
    pid: pid_t = 100
) -> WindowInfo {
    WindowInfo(
        id: UUID(),
        pid: pid,
        appName: "TestApp",
        appIcon: nil,
        title: title,
        isMinimized: isMinimized,
        isHidden: isHidden,
        axElement: nil
    )
}

func runWindowInfoTests() {
    // PRD 4.B: empty title falls back to "Untitled"
    expectEqual(makeWindow(title: "").displayTitle, "Untitled",
                "empty title falls back to Untitled")
    expectEqual(makeWindow(title: "report.pdf").displayTitle, "report.pdf",
                "non-empty title used as-is")

    // Minimized windows get the injected suffix (default " (minimized)")
    expectEqual(makeWindow(title: "Notes", isMinimized: true).displayTitle, "Notes (minimized)",
                "minimized title gets suffix")
    expectEqual(makeWindow(title: "", isMinimized: true).displayTitle, "Untitled (minimized)",
                "minimized untitled gets fallback and suffix")
    // Injected localized strings are used when provided
    expectEqual(makeWindow(title: "", isMinimized: true).displayTitle(untitled: "제목 없음", minimizedSuffix: " (최소화됨)"),
                "제목 없음 (최소화됨)", "injected localized strings are applied")

    // PRD 4.A: setting OFF excludes minimized AND hidden windows entirely
    let mixed = [
        makeWindow(title: "normal"),
        makeWindow(title: "min", isMinimized: true),
        makeWindow(title: "hid", isHidden: true),
    ]
    expectEqual(WindowInfo.visibleWindows(mixed, includeMinimized: false).map(\.title), ["normal"],
                "setting OFF filters minimized and hidden")
    expectEqual(WindowInfo.visibleWindows(mixed, includeMinimized: true).map(\.title), ["normal", "min", "hid"],
                "setting ON keeps minimized and hidden")

    // Same-App Switch: filter by pid
    let perApp = [
        makeWindow(title: "a", pid: 1),
        makeWindow(title: "b", pid: 2),
        makeWindow(title: "c", pid: 1),
    ]
    expectEqual(perApp.filter { $0.pid == 1 }.map(\.title), ["a", "c"],
                "filter by pid keeps only that app's windows")
}
