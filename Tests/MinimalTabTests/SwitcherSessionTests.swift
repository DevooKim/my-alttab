import Foundation
import MinimalTabCore

private func makeWindows(_ count: Int) -> [WindowInfo] {
    (0..<count).map { i in
        WindowInfo(id: UUID(), pid: pid_t(i), appName: "App\(i)", appIcon: nil,
                   title: "W\(i)", isMinimized: false, isHidden: false, axElement: nil)
    }
}

func runSwitcherSessionTests() {
    // Alt-Tab convention: the first trigger press selects the *second*
    // window (index 1), because index 0 is the currently focused window.
    expectEqual(SwitcherSession(windows: makeWindows(3)).selectedIndex, 1,
                "initial selection is second window")
    expectEqual(SwitcherSession(windows: makeWindows(1)).selectedIndex, 0,
                "single window selects index 0")

    var session = SwitcherSession(windows: makeWindows(3))
    session.advance()
    expectEqual(session.selectedIndex, 2, "advance moves forward")
    session.advance()
    expectEqual(session.selectedIndex, 0, "advance wraps around")

    var back = SwitcherSession(windows: makeWindows(3))
    back.retreat()
    expectEqual(back.selectedIndex, 0, "retreat moves backward")
    back.retreat()
    expectEqual(back.selectedIndex, 2, "retreat wraps around")

    let windows = makeWindows(3)
    expectEqual(SwitcherSession(windows: windows).selectedWindow, windows[1],
                "selectedWindow returns highlighted window")

    let empty = SwitcherSession(windows: [])
    expect(empty.selectedWindow == nil, "selectedWindow nil when empty")
    expectEqual(empty.selectedIndex, 0, "empty session index is 0")

    var emptyMut = SwitcherSession(windows: [])
    emptyMut.advance()
    emptyMut.retreat()
    expectEqual(emptyMut.selectedIndex, 0, "advance/retreat on empty does not crash")

    var direct = SwitcherSession(windows: makeWindows(5))
    direct.select(index: 3)
    expectEqual(direct.selectedIndex, 3, "select(index:) jumps directly")
    direct.select(index: 99)
    expectEqual(direct.selectedIndex, 3, "out-of-range select is ignored")
}
