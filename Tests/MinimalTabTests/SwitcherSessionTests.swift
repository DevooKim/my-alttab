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

    // Quick Actions: removing the selected window keeps the session usable
    var removal = SwitcherSession(windows: makeWindows(3)) // selected: W1
    let removed = removal.removeSelected()
    expectEqual(removed?.title, "W1", "removeSelected returns the removed window")
    expectEqual(removal.windows.map(\.title), ["W0", "W2"], "removed window leaves the list")
    expectEqual(removal.selectedWindow?.title, "W2", "selection moves to the next window")

    var removeLast = SwitcherSession(windows: makeWindows(2))
    removeLast.advance() // wrap to 0
    removeLast.select(index: 1)
    _ = removeLast.removeSelected()
    expectEqual(removeLast.selectedIndex, 0, "removing the last item clamps the index")

    var removeAll = SwitcherSession(windows: makeWindows(1))
    _ = removeAll.removeSelected()
    expect(removeAll.selectedWindow == nil, "removing the only window empties the session")
    expect(removeAll.removeSelected() == nil, "removeSelected on empty returns nil")

    // Quick Actions: quitting an app removes every window of that pid
    let multi = [
        WindowInfo(id: UUID(), pid: 1, appName: "A", appIcon: nil, title: "a1",
                   isMinimized: false, isHidden: false, axElement: nil),
        WindowInfo(id: UUID(), pid: 2, appName: "B", appIcon: nil, title: "b1",
                   isMinimized: false, isHidden: false, axElement: nil),
        WindowInfo(id: UUID(), pid: 1, appName: "A", appIcon: nil, title: "a2",
                   isMinimized: false, isHidden: false, axElement: nil),
    ]
    var quit = SwitcherSession(windows: multi) // selected: b1
    quit.select(index: 0)
    quit.removeWindows(pid: 1)
    expectEqual(quit.windows.map(\.title), ["b1"], "removeWindows(pid:) drops all of that app")
    expectEqual(quit.selectedIndex, 0, "selection clamps after pid removal")
}
