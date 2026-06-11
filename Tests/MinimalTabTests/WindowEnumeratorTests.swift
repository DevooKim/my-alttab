import Foundation
import MinimalTabCore

private func makeWindow(pid: pid_t, title: String, isMinimized: Bool = false) -> WindowInfo {
    WindowInfo(id: UUID(), pid: pid, appName: "App\(pid)", appIcon: nil,
               title: title, isMinimized: isMinimized, isHidden: false, axElement: nil)
}

func runWindowEnumeratorTests() {
    // z-order says: pid 10 frontmost, then 20, then 30
    let mixed = [
        makeWindow(pid: 30, title: "c1"),
        makeWindow(pid: 30, title: "c2"),
        makeWindow(pid: 10, title: "a1"),
        makeWindow(pid: 20, title: "b1"),
    ]
    expectEqual(WindowEnumerator.sortByZOrder(mixed, pidRank: [10: 0, 20: 1, 30: 2]).map(\.title),
                ["a1", "b1", "c1", "c2"],
                "sorts by z-order rank, keeps AX order within app")

    let withMinimized = [
        makeWindow(pid: 10, title: "min", isMinimized: true),
        makeWindow(pid: 10, title: "front"),
        makeWindow(pid: 20, title: "back"),
    ]
    expectEqual(WindowEnumerator.sortByZOrder(withMinimized, pidRank: [10: 0, 20: 1]).map(\.title),
                ["front", "back", "min"],
                "minimized windows go last")

    // Hidden apps have no on-screen windows, so their pid is absent
    // from the CGWindowList ranking.
    let withUnranked = [
        makeWindow(pid: 99, title: "hiddenApp"),
        makeWindow(pid: 10, title: "front"),
    ]
    expectEqual(WindowEnumerator.sortByZOrder(withUnranked, pidRank: [10: 0]).map(\.title),
                ["front", "hiddenApp"],
                "unranked pids go after ranked ones")
}
