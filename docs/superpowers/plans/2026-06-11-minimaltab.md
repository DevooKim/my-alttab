# MinimalTab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A macOS menu-bar utility that switches windows via a text-only (app name + window title) popup, triggered by holding Option+Tab (all apps) or Option+` (current app only), with no screen-capture permission required.

**Architecture:** A Swift Package Manager executable, bundled into a `.app` via a script. Window enumeration uses the Accessibility API (`AXUIElement`) — *not* `kCGWindowName`, which would require Screen Recording permission; `CGWindowListCopyWindowInfo` is used only for z-ordering (PIDs/order are readable without extra permission). A `CGEventTap` (requires the same Accessibility permission) implements the hold-modifier/press-trigger/release-to-commit interaction. Pure logic (filtering, title fallback, selection cycling, shortcut matching) lives in plain structs and is unit-tested; system-API layers are thin and verified via a manual smoke-test checklist.

**Tech Stack:** Swift 6.2 (language mode 5), SwiftUI (panel content + settings), AppKit (NSPanel, NSStatusItem, NSVisualEffectView), ApplicationServices (AXUIElement, CGEventTap), ServiceManagement (SMAppService for launch-at-login), XCTest, SwiftPM.

**Deployment target:** macOS 13+ (required by `SMAppService`).

---

## File Structure

```
my_alttab/
├── Package.swift
├── Makefile                                  # build + bundle + test shortcuts
├── scripts/bundle.sh                         # assembles MinimalTab.app from the SPM binary
├── Resources/Info.plist                      # LSUIElement=true, bundle id
├── Sources/MinimalTab/
│   ├── main.swift                            # NSApplication bootstrap
│   ├── AppDelegate.swift                     # wiring: status bar, permission, hotkeys, controller
│   ├── Models/WindowInfo.swift               # window model + displayTitle fallback + filtering (pure)
│   ├── Models/KeyboardShortcut.swift         # keyCode+modifiers, Codable, matching (pure)
│   ├── Models/SwitcherSession.swift          # selection cycling state machine (pure)
│   ├── Preferences.swift                     # UserDefaults-backed settings (keys shared with @AppStorage)
│   ├── System/AccessibilityPermission.swift  # AXIsProcessTrusted check + prompt alert
│   ├── System/WindowEnumerator.swift         # AX enumeration + CGWindowList z-order
│   ├── System/WindowActivator.swift          # unminimize / unhide / raise / activate
│   ├── System/HotKeyMonitor.swift            # CGEventTap: keyDown trigger + flagsChanged release
│   ├── System/LaunchAtLogin.swift            # SMAppService wrapper
│   ├── UI/SwitcherController.swift           # orchestrates session: show, cycle, commit, cancel
│   ├── UI/SwitcherPanel.swift                # non-activating borderless NSPanel, mouse-screen centering
│   ├── UI/SwitcherView.swift                 # SwiftUI frosted-glass list
│   ├── UI/StatusBarController.swift          # NSStatusItem + menu
│   ├── UI/SettingsWindowController.swift     # hosts SettingsView in an NSWindow
│   ├── UI/SettingsView.swift                 # toggles + launch at login (SwiftUI)
│   └── UI/ShortcutRecorderView.swift         # click-to-record shortcut field
└── Tests/MinimalTabTests/
    ├── WindowInfoTests.swift
    ├── KeyboardShortcutTests.swift
    └── SwitcherSessionTests.swift
```

**Design constraints locked in here:**
- All testable logic is in `Models/` with zero AppKit/AX dependencies (`WindowInfo.axElement` is optional so tests can construct instances).
- `System/` files are thin wrappers around system APIs; no business logic.
- Swift language mode 5 in `Package.swift` to avoid Swift 6 strict-concurrency friction with C callbacks (CGEventTap) and AX APIs. UI types are `@MainActor` where natural.

---

### Task 1: Project scaffold (SPM package, git, Makefile, bundle script)

**Files:**
- Create: `Package.swift`
- Create: `.gitignore`
- Create: `Resources/Info.plist`
- Create: `scripts/bundle.sh`
- Create: `Makefile`
- Create: `Sources/MinimalTab/main.swift` (placeholder)
- Create: `Tests/MinimalTabTests/SmokeTests.swift` (placeholder)

- [ ] **Step 1: Initialize git**

```bash
cd /Users/hyunwookim/Dev/apps/my_alttab && git init -b main
```

- [ ] **Step 2: Write `.gitignore`**

```gitignore
.build/
.swiftpm/
dist/
*.xcodeproj
.DS_Store
```

- [ ] **Step 3: Write `Package.swift`**

```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MinimalTab",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MinimalTab",
            path: "Sources/MinimalTab"
        ),
        .testTarget(
            name: "MinimalTabTests",
            dependencies: ["MinimalTab"],
            path: "Tests/MinimalTabTests"
        ),
    ]
)
```

- [ ] **Step 4: Write placeholder `Sources/MinimalTab/main.swift`**

```swift
import AppKit

print("MinimalTab placeholder")
```

- [ ] **Step 5: Write placeholder `Tests/MinimalTabTests/SmokeTests.swift`**

```swift
import XCTest

final class SmokeTests: XCTestCase {
    func testScaffoldBuilds() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 6: Verify build and tests run**

Run: `swift build && swift test`
Expected: `Build complete!` and `Test Suite 'All tests' passed` (1 test).

- [ ] **Step 7: Write `Resources/Info.plist`** (LSUIElement hides the Dock icon — PRD §3.A)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>MinimalTab</string>
    <key>CFBundleDisplayName</key>
    <string>MinimalTab</string>
    <key>CFBundleIdentifier</key>
    <string>io.goorm.minimaltab</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleExecutable</key>
    <string>MinimalTab</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 8: Write `scripts/bundle.sh`**

```bash
#!/bin/bash
# Assembles dist/MinimalTab.app from the SPM release binary.
# Note: ad-hoc signing changes per build, so macOS may require re-granting
# Accessibility permission after each rebuild (toggle the entry off/on in
# System Settings > Privacy & Security > Accessibility).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP=dist/MinimalTab.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp .build/release/MinimalTab "$APP/Contents/MacOS/MinimalTab"
codesign --force --sign - "$APP"
echo "Bundled: $APP"
```

- [ ] **Step 9: Write `Makefile`**

```makefile
.PHONY: build test app run

build:
	swift build

test:
	swift test

app:
	bash scripts/bundle.sh

run: app
	open dist/MinimalTab.app
```

- [ ] **Step 10: Verify bundling works**

Run: `chmod +x scripts/bundle.sh && make app && ls dist/MinimalTab.app/Contents/MacOS`
Expected: prints `MinimalTab` (the binary exists inside the bundle).

- [ ] **Step 11: Commit**

```bash
git add -A
git commit -m "chore: scaffold SPM package, app bundling script, Makefile"
```

---

### Task 2: WindowInfo model — title fallback, minimized decoration, filtering

Implements PRD §4.A (minimized filtering/decoration) and §4.B (Untitled fallback) as pure logic.

**Files:**
- Create: `Sources/MinimalTab/Models/WindowInfo.swift`
- Create: `Tests/MinimalTabTests/WindowInfoTests.swift`
- Delete: `Tests/MinimalTabTests/SmokeTests.swift`

- [ ] **Step 1: Write the failing tests**

`Tests/MinimalTabTests/WindowInfoTests.swift`:

```swift
import XCTest
@testable import MinimalTab

final class WindowInfoTests: XCTestCase {
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

    // PRD 4.B: empty title falls back to "Untitled"
    func testEmptyTitleFallsBackToUntitled() {
        XCTAssertEqual(makeWindow(title: "").displayTitle, "Untitled")
    }

    func testNonEmptyTitleIsUsedAsIs() {
        XCTAssertEqual(makeWindow(title: "report.pdf").displayTitle, "report.pdf")
    }

    // PRD 4.A: minimized windows get a "(최소화됨)" suffix
    func testMinimizedTitleGetsSuffix() {
        XCTAssertEqual(makeWindow(title: "Notes", isMinimized: true).displayTitle, "Notes (최소화됨)")
    }

    func testMinimizedUntitledGetsBothFallbackAndSuffix() {
        XCTAssertEqual(makeWindow(title: "", isMinimized: true).displayTitle, "Untitled (최소화됨)")
    }

    // PRD 4.A: setting OFF excludes minimized AND hidden windows entirely
    func testFilterExcludesMinimizedAndHiddenWhenSettingOff() {
        let windows = [
            makeWindow(title: "normal"),
            makeWindow(title: "min", isMinimized: true),
            makeWindow(title: "hid", isHidden: true),
        ]
        let result = WindowInfo.visibleWindows(windows, includeMinimized: false)
        XCTAssertEqual(result.map(\.title), ["normal"])
    }

    // PRD 4.A: setting ON includes them
    func testFilterIncludesMinimizedAndHiddenWhenSettingOn() {
        let windows = [
            makeWindow(title: "normal"),
            makeWindow(title: "min", isMinimized: true),
            makeWindow(title: "hid", isHidden: true),
        ]
        let result = WindowInfo.visibleWindows(windows, includeMinimized: true)
        XCTAssertEqual(result.map(\.title), ["normal", "min", "hid"])
    }

    // Same-App Switch: filter by pid
    func testFilterByPid() {
        let windows = [
            makeWindow(title: "a", pid: 1),
            makeWindow(title: "b", pid: 2),
            makeWindow(title: "c", pid: 1),
        ]
        let result = windows.filter { $0.pid == 1 }
        XCTAssertEqual(result.map(\.title), ["a", "c"])
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `rm Tests/MinimalTabTests/SmokeTests.swift && swift test`
Expected: FAIL to compile — `cannot find 'WindowInfo' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/MinimalTab/Models/WindowInfo.swift`:

```swift
import AppKit
import ApplicationServices

/// One switchable window. `axElement` is optional so pure-logic tests can
/// construct instances without touching the Accessibility API.
struct WindowInfo: Identifiable, Equatable {
    let id: UUID
    let pid: pid_t
    let appName: String
    let appIcon: NSImage?
    let title: String
    let isMinimized: Bool
    /// True when the owning app is hidden (Cmd+H).
    let isHidden: Bool
    let axElement: AXUIElement?

    /// PRD 4.B: empty titles fall back to "Untitled".
    /// PRD 4.A: minimized windows are suffixed with "(최소화됨)".
    var displayTitle: String {
        let base = title.isEmpty ? "Untitled" : title
        return isMinimized ? base + " (최소화됨)" : base
    }

    /// PRD 4.A: with the setting OFF, minimized/hidden windows are removed
    /// from the list entirely.
    static func visibleWindows(_ all: [WindowInfo], includeMinimized: Bool) -> [WindowInfo] {
        includeMinimized ? all : all.filter { !$0.isMinimized && !$0.isHidden }
    }

    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.id == rhs.id
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: PASS, 7 tests.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: WindowInfo model with Untitled fallback, minimized suffix, visibility filtering"
```

---

### Task 3: KeyboardShortcut model — storage codec and event matching

**Files:**
- Create: `Sources/MinimalTab/Models/KeyboardShortcut.swift`
- Create: `Tests/MinimalTabTests/KeyboardShortcutTests.swift`

- [ ] **Step 1: Write the failing tests**

`Tests/MinimalTabTests/KeyboardShortcutTests.swift`:

```swift
import XCTest
import CoreGraphics
@testable import MinimalTab

final class KeyboardShortcutTests: XCTestCase {
    func testDefaults() {
        XCTAssertEqual(KeyboardShortcut.globalDefault.keyCode, 48)  // Tab
        XCTAssertEqual(KeyboardShortcut.sameAppDefault.keyCode, 50) // backtick (`)
        XCTAssertEqual(KeyboardShortcut.globalDefault.modifiers, CGEventFlags.maskAlternate.rawValue)
    }

    func testMatchesExactKeyAndModifier() {
        let s = KeyboardShortcut.globalDefault
        XCTAssertTrue(s.matches(keyCode: 48, flags: .maskAlternate))
    }

    func testDoesNotMatchWrongKey() {
        XCTAssertFalse(KeyboardShortcut.globalDefault.matches(keyCode: 49, flags: .maskAlternate))
    }

    func testDoesNotMatchMissingModifier() {
        XCTAssertFalse(KeyboardShortcut.globalDefault.matches(keyCode: 48, flags: []))
    }

    func testDoesNotMatchExtraRelevantModifier() {
        // Option+Cmd+Tab must NOT trigger an Option+Tab shortcut.
        let flags: CGEventFlags = [.maskAlternate, .maskCommand]
        XCTAssertFalse(KeyboardShortcut.globalDefault.matches(keyCode: 48, flags: flags))
    }

    func testIgnoresIrrelevantHardwareFlags() {
        // Real CGEvents carry extra bits (e.g. maskNonCoalesced, left/right
        // distinction). Matching must mask those out.
        let flags = CGEventFlags(rawValue: CGEventFlags.maskAlternate.rawValue | 0x20) // 0x20 = NX_DEVICELALTKEYMASK
        XCTAssertTrue(KeyboardShortcut.globalDefault.matches(keyCode: 48, flags: flags))
    }

    func testModifiersStillHeldDetectsRelease() {
        let s = KeyboardShortcut.globalDefault
        XCTAssertTrue(s.modifiersStillHeld(flags: .maskAlternate))
        XCTAssertFalse(s.modifiersStillHeld(flags: []))
        XCTAssertFalse(s.modifiersStillHeld(flags: .maskShift))
    }

    func testCodableRoundTrip() throws {
        let s = KeyboardShortcut(keyCode: 49, modifiers: CGEventFlags.maskControl.rawValue)
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(KeyboardShortcut.self, from: data)
        XCTAssertEqual(s, back)
    }

    func testDisplayString() {
        XCTAssertEqual(KeyboardShortcut.globalDefault.displayString, "⌥⇥")
        let ctrlSpace = KeyboardShortcut(keyCode: 49, modifiers: CGEventFlags.maskControl.rawValue)
        XCTAssertEqual(ctrlSpace.displayString, "⌃Space")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test`
Expected: FAIL to compile — `cannot find 'KeyboardShortcut' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/MinimalTab/Models/KeyboardShortcut.swift`:

```swift
import CoreGraphics

/// A user-configurable shortcut: one trigger key + required modifier mask.
/// Stored in UserDefaults as JSON via `Preferences`.
struct KeyboardShortcut: Codable, Equatable {
    var keyCode: UInt16
    /// Raw CGEventFlags, already restricted to `relevantModifierMask` bits.
    var modifiers: UInt64

    /// The modifier bits we compare; everything else on a real CGEvent
    /// (non-coalesced flag, left/right device bits, caps lock) is ignored.
    static let relevantModifierMask: UInt64 =
        CGEventFlags.maskCommand.rawValue
        | CGEventFlags.maskAlternate.rawValue
        | CGEventFlags.maskControl.rawValue
        | CGEventFlags.maskShift.rawValue

    static let globalDefault = KeyboardShortcut(
        keyCode: 48, // kVK_Tab
        modifiers: CGEventFlags.maskAlternate.rawValue
    )
    static let sameAppDefault = KeyboardShortcut(
        keyCode: 50, // kVK_ANSI_Grave (`)
        modifiers: CGEventFlags.maskAlternate.rawValue
    )

    /// True when a keyDown event is exactly this shortcut (no extra
    /// relevant modifiers allowed).
    func matches(keyCode: Int64, flags: CGEventFlags) -> Bool {
        guard keyCode == Int64(self.keyCode) else { return false }
        return (flags.rawValue & Self.relevantModifierMask) == modifiers
    }

    /// True while every required modifier is still pressed — used on
    /// flagsChanged events to detect release-to-commit.
    func modifiersStillHeld(flags: CGEventFlags) -> Bool {
        (flags.rawValue & modifiers) == modifiers && modifiers != 0
    }

    var displayString: String {
        var s = ""
        if modifiers & CGEventFlags.maskControl.rawValue != 0 { s += "⌃" }
        if modifiers & CGEventFlags.maskAlternate.rawValue != 0 { s += "⌥" }
        if modifiers & CGEventFlags.maskShift.rawValue != 0 { s += "⇧" }
        if modifiers & CGEventFlags.maskCommand.rawValue != 0 { s += "⌘" }
        s += Self.keyName(for: keyCode)
        return s
    }

    static func keyName(for keyCode: UInt16) -> String {
        let names: [UInt16: String] = [
            48: "⇥", 50: "`", 49: "Space", 36: "↩", 53: "⎋", 51: "⌫",
            0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G",
            4: "H", 34: "I", 38: "J", 40: "K", 37: "L", 46: "M", 45: "N",
            31: "O", 35: "P", 12: "Q", 15: "R", 1: "S", 17: "T", 32: "U",
            9: "V", 13: "W", 7: "X", 16: "Y", 6: "Z",
            18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6",
            26: "7", 28: "8", 25: "9", 29: "0",
            123: "←", 124: "→", 125: "↓", 126: "↑",
        ]
        return names[keyCode] ?? "key\(keyCode)"
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: PASS (16 tests total).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: KeyboardShortcut model with event matching and display string"
```

---

### Task 4: SwitcherSession — selection cycling state machine

Implements PRD §2.C interaction model as pure state: trigger advances selection, release commits the selected window.

**Files:**
- Create: `Sources/MinimalTab/Models/SwitcherSession.swift`
- Create: `Tests/MinimalTabTests/SwitcherSessionTests.swift`

- [ ] **Step 1: Write the failing tests**

`Tests/MinimalTabTests/SwitcherSessionTests.swift`:

```swift
import XCTest
@testable import MinimalTab

final class SwitcherSessionTests: XCTestCase {
    private func makeWindows(_ count: Int) -> [WindowInfo] {
        (0..<count).map { i in
            WindowInfo(id: UUID(), pid: pid_t(i), appName: "App\(i)", appIcon: nil,
                       title: "W\(i)", isMinimized: false, isHidden: false, axElement: nil)
        }
    }

    // Alt-Tab convention: the first trigger press selects the *second*
    // window (index 1), because index 0 is the currently focused window.
    func testInitialSelectionIsSecondWindow() {
        let session = SwitcherSession(windows: makeWindows(3))
        XCTAssertEqual(session.selectedIndex, 1)
    }

    func testInitialSelectionWithSingleWindowIsZero() {
        let session = SwitcherSession(windows: makeWindows(1))
        XCTAssertEqual(session.selectedIndex, 0)
    }

    func testAdvanceMovesForward() {
        var session = SwitcherSession(windows: makeWindows(3))
        session.advance()
        XCTAssertEqual(session.selectedIndex, 2)
    }

    func testAdvanceWrapsAround() {
        var session = SwitcherSession(windows: makeWindows(3))
        session.advance() // -> 2
        session.advance() // wraps -> 0
        XCTAssertEqual(session.selectedIndex, 0)
    }

    func testRetreatMovesBackwardAndWraps() {
        var session = SwitcherSession(windows: makeWindows(3))
        session.retreat() // 1 -> 0
        XCTAssertEqual(session.selectedIndex, 0)
        session.retreat() // wraps -> 2
        XCTAssertEqual(session.selectedIndex, 2)
    }

    func testSelectedWindow() {
        let windows = makeWindows(3)
        let session = SwitcherSession(windows: windows)
        XCTAssertEqual(session.selectedWindow, windows[1])
    }

    func testSelectedWindowIsNilWhenEmpty() {
        let session = SwitcherSession(windows: [])
        XCTAssertNil(session.selectedWindow)
        XCTAssertEqual(session.selectedIndex, 0)
    }

    func testAdvanceOnEmptyDoesNotCrash() {
        var session = SwitcherSession(windows: [])
        session.advance()
        session.retreat()
        XCTAssertEqual(session.selectedIndex, 0)
    }

    func testSelectIndexDirectly() {
        var session = SwitcherSession(windows: makeWindows(5))
        session.select(index: 3)
        XCTAssertEqual(session.selectedIndex, 3)
        session.select(index: 99) // out of range: ignored
        XCTAssertEqual(session.selectedIndex, 3)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test`
Expected: FAIL to compile — `cannot find 'SwitcherSession' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/MinimalTab/Models/SwitcherSession.swift`:

```swift
import Foundation

/// Pure selection state for one switcher invocation (modifier held down).
/// Created when the trigger first fires, discarded on commit/cancel.
struct SwitcherSession {
    let windows: [WindowInfo]
    private(set) var selectedIndex: Int

    init(windows: [WindowInfo]) {
        self.windows = windows
        // Index 0 is the frontmost (current) window, so the first trigger
        // press should land on the next one — standard Alt-Tab behavior.
        self.selectedIndex = windows.count > 1 ? 1 : 0
    }

    var selectedWindow: WindowInfo? {
        windows.indices.contains(selectedIndex) ? windows[selectedIndex] : nil
    }

    mutating func advance() {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % windows.count
    }

    mutating func retreat() {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + windows.count) % windows.count
    }

    mutating func select(index: Int) {
        guard windows.indices.contains(index) else { return }
        selectedIndex = index
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: PASS (25 tests total).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: SwitcherSession cycling state machine"
```

---

### Task 5: Preferences — UserDefaults-backed settings

PRD §3.B. Keys are plain strings so SwiftUI `@AppStorage` and AppKit code share the same store.

**Files:**
- Create: `Sources/MinimalTab/Preferences.swift`
- Create: `Tests/MinimalTabTests/PreferencesTests.swift`

- [ ] **Step 1: Write the failing tests**

`Tests/MinimalTabTests/PreferencesTests.swift`:

```swift
import XCTest
@testable import MinimalTab

final class PreferencesTests: XCTestCase {
    private var defaults: UserDefaults!
    private var prefs: Preferences!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "test.minimaltab")!
        defaults.removePersistentDomain(forName: "test.minimaltab")
        prefs = Preferences(defaults: defaults)
    }

    func testIncludeMinimizedDefaultsToTrue() {
        XCTAssertTrue(prefs.includeMinimized)
    }

    func testIncludeMinimizedPersists() {
        prefs.includeMinimized = false
        XCTAssertFalse(Preferences(defaults: defaults).includeMinimized)
    }

    func testShortcutsDefaultToOptionTabAndOptionBacktick() {
        XCTAssertEqual(prefs.globalShortcut, .globalDefault)
        XCTAssertEqual(prefs.sameAppShortcut, .sameAppDefault)
    }

    func testShortcutRoundTrips() {
        let custom = KeyboardShortcut(keyCode: 49, modifiers: CGEventFlags.maskControl.rawValue)
        prefs.globalShortcut = custom
        XCTAssertEqual(Preferences(defaults: defaults).globalShortcut, custom)
    }

    func testCorruptShortcutDataFallsBackToDefault() {
        defaults.set(Data([0x00, 0x01]), forKey: Preferences.Key.globalShortcut)
        XCTAssertEqual(prefs.globalShortcut, .globalDefault)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test`
Expected: FAIL to compile — `cannot find 'Preferences' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/MinimalTab/Preferences.swift`:

```swift
import Foundation

/// Settings store. Key strings are shared with SwiftUI @AppStorage in
/// SettingsView, so both sides read/write the same UserDefaults entries.
final class Preferences {
    enum Key {
        static let includeMinimized = "includeMinimized"
        static let globalShortcut = "globalShortcut"
        static let sameAppShortcut = "sameAppShortcut"
    }

    static let shared = Preferences()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Key.includeMinimized: true])
    }

    var includeMinimized: Bool {
        get { defaults.bool(forKey: Key.includeMinimized) }
        set { defaults.set(newValue, forKey: Key.includeMinimized) }
    }

    var globalShortcut: KeyboardShortcut {
        get { readShortcut(Key.globalShortcut) ?? .globalDefault }
        set { writeShortcut(newValue, key: Key.globalShortcut) }
    }

    var sameAppShortcut: KeyboardShortcut {
        get { readShortcut(Key.sameAppShortcut) ?? .sameAppDefault }
        set { writeShortcut(newValue, key: Key.sameAppShortcut) }
    }

    private func readShortcut(_ key: String) -> KeyboardShortcut? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(KeyboardShortcut.self, from: data)
    }

    private func writeShortcut(_ shortcut: KeyboardShortcut, key: String) {
        defaults.set(try? JSONEncoder().encode(shortcut), forKey: key)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: PASS (30 tests total).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: Preferences store with shortcut persistence and defaults"
```

---

### Task 6: Accessibility permission check + prompt

PRD §4.D. System-API wrapper; verified manually in the final smoke test.

**Files:**
- Create: `Sources/MinimalTab/System/AccessibilityPermission.swift`

- [ ] **Step 1: Write the implementation**

`Sources/MinimalTab/System/AccessibilityPermission.swift`:

```swift
import AppKit
import ApplicationServices

enum AccessibilityPermission {
    static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    /// PRD 4.D: on first launch without permission, show an alert that
    /// jumps straight to System Settings > Privacy & Security > Accessibility.
    @MainActor
    static func promptIfNeeded() {
        guard !isGranted else { return }

        // Also registers the app in the Accessibility list so the user
        // only has to flip the toggle.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        let alert = NSAlert()
        alert.messageText = "손쉬운 사용 권한이 필요합니다"
        alert.informativeText = """
        MinimalTab은 다른 앱의 윈도우 목록을 가져오고 포커스를 제어하기 위해 \
        손쉬운 사용(Accessibility) 권한이 필요합니다.

        시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용에서 MinimalTab을 허용한 뒤 앱을 다시 실행해 주세요.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "시스템 설정 열기")
        alert.addButton(withTitle: "나중에")

        if alert.runModal() == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: accessibility permission check with System Settings deep link"
```

---

### Task 7: WindowEnumerator — AX-based window listing with CGWindowList z-order

PRD §2.B, §4.A. Titles come from `kAXTitleAttribute` (Accessibility permission only — never `kCGWindowName`, which would require Screen Recording). Z-order comes from `CGWindowListCopyWindowInfo` PID order, which is readable without extra permission.

**Files:**
- Create: `Sources/MinimalTab/System/WindowEnumerator.swift`
- Create: `Tests/MinimalTabTests/WindowEnumeratorTests.swift`

- [ ] **Step 1: Write the failing test for the pure ordering helper**

`Tests/MinimalTabTests/WindowEnumeratorTests.swift`:

```swift
import XCTest
@testable import MinimalTab

final class WindowEnumeratorTests: XCTestCase {
    private func makeWindow(pid: pid_t, title: String, isMinimized: Bool = false) -> WindowInfo {
        WindowInfo(id: UUID(), pid: pid, appName: "App\(pid)", appIcon: nil,
                   title: title, isMinimized: isMinimized, isHidden: false, axElement: nil)
    }

    func testSortsByZOrderRankThenKeepsAXOrderWithinApp() {
        let windows = [
            makeWindow(pid: 30, title: "c1"),
            makeWindow(pid: 30, title: "c2"),
            makeWindow(pid: 10, title: "a1"),
            makeWindow(pid: 20, title: "b1"),
        ]
        // z-order says: pid 10 frontmost, then 20, then 30
        let sorted = WindowEnumerator.sortByZOrder(windows, pidRank: [10: 0, 20: 1, 30: 2])
        XCTAssertEqual(sorted.map(\.title), ["a1", "b1", "c1", "c2"])
    }

    func testMinimizedWindowsGoLast() {
        let windows = [
            makeWindow(pid: 10, title: "min", isMinimized: true),
            makeWindow(pid: 10, title: "front"),
            makeWindow(pid: 20, title: "back"),
        ]
        let sorted = WindowEnumerator.sortByZOrder(windows, pidRank: [10: 0, 20: 1])
        XCTAssertEqual(sorted.map(\.title), ["front", "back", "min"])
    }

    func testUnrankedPidsGoAfterRankedOnes() {
        // Hidden apps have no on-screen windows, so their pid is absent
        // from the CGWindowList ranking.
        let windows = [
            makeWindow(pid: 99, title: "hiddenApp"),
            makeWindow(pid: 10, title: "front"),
        ]
        let sorted = WindowEnumerator.sortByZOrder(windows, pidRank: [10: 0])
        XCTAssertEqual(sorted.map(\.title), ["front", "hiddenApp"])
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test`
Expected: FAIL to compile — `cannot find 'WindowEnumerator' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/MinimalTab/System/WindowEnumerator.swift`:

```swift
import AppKit
import ApplicationServices

/// Lists switchable windows via the Accessibility API.
///
/// IMPORTANT: window titles deliberately come from kAXTitleAttribute, NOT
/// kCGWindowName — the latter is redacted unless the app holds Screen
/// Recording permission, which this app must never request (PRD 2.B).
struct WindowEnumerator {
    /// All windows of all regular apps, front-to-back, minimized last.
    func allWindows() -> [WindowInfo] {
        var windows: [WindowInfo] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            windows.append(contentsOf: windowsOf(app: app))
        }
        return Self.sortByZOrder(windows, pidRank: Self.currentPidRank())
    }

    /// Windows of the frontmost app only (Same-App Switch, PRD 2.C).
    func frontmostAppWindows() -> [WindowInfo] {
        guard let app = NSWorkspace.shared.frontmostApplication else { return [] }
        return Self.sortByZOrder(windowsOf(app: app), pidRank: Self.currentPidRank())
    }

    private func windowsOf(app: NSRunningApplication) -> [WindowInfo] {
        let pid = app.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)
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

    /// Front-to-back rank per PID from the on-screen window list. Reads
    /// only PIDs/order — no window names — so no extra permission needed.
    static func currentPidRank() -> [pid_t: Int] {
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

    /// Pure, unit-tested ordering: apps in z-order (unranked apps last,
    /// e.g. hidden apps with no on-screen windows), AX order kept within
    /// an app, minimized windows pushed to the end.
    static func sortByZOrder(_ windows: [WindowInfo], pidRank: [pid_t: Int]) -> [WindowInfo] {
        let indexed = windows.enumerated()
        let sorted = indexed.sorted { a, b in
            let keyA = (a.element.isMinimized ? 1 : 0, pidRank[a.element.pid] ?? Int.max, a.offset)
            let keyB = (b.element.isMinimized ? 1 : 0, pidRank[b.element.pid] ?? Int.max, b.offset)
            return keyA < keyB
        }
        return sorted.map(\.element)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: PASS (33 tests total).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: AX-based window enumerator with permission-free z-ordering"
```

---

### Task 8: WindowActivator — unminimize, unhide, raise, focus

PRD §2.C (release activates window) and §4.A (selecting a minimized/hidden item restores it).

**Files:**
- Create: `Sources/MinimalTab/System/WindowActivator.swift`

- [ ] **Step 1: Write the implementation**

`Sources/MinimalTab/System/WindowActivator.swift`:

```swift
import AppKit
import ApplicationServices

struct WindowActivator {
    /// Brings the window to the front, restoring it first if minimized or
    /// if its app is hidden (PRD 4.A).
    func activate(_ window: WindowInfo) {
        guard let axElement = window.axElement else { return }
        let app = NSRunningApplication(processIdentifier: window.pid)

        if window.isMinimized {
            AXUIElementSetAttributeValue(axElement, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        if let app, app.isHidden {
            app.unhide()
        }

        // Raise the specific window, then focus its app. Order matters:
        // raising first makes this window the app's frontmost, so app
        // activation focuses it rather than another window.
        AXUIElementSetAttributeValue(axElement, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(axElement, kAXRaiseAction as CFString)
        app?.activate()
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build`
Expected: `Build complete!` (a deprecation warning on `activate()` vs `activate(options:)` is acceptable; if one appears, use `app?.activate(options: [.activateIgnoringOtherApps])` instead).

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: WindowActivator with unminimize/unhide/raise"
```

---

### Task 9: HotKeyMonitor — CGEventTap for trigger and modifier release

PRD §2.C. Listens globally for keyDown (trigger/repeat) and flagsChanged (release-to-commit). Consumes matching keyDown events so the focused app never sees them. Escape cancels an active session.

**Files:**
- Create: `Sources/MinimalTab/System/HotKeyMonitor.swift`

- [ ] **Step 1: Write the implementation**

`Sources/MinimalTab/System/HotKeyMonitor.swift`:

```swift
import AppKit
import CoreGraphics

enum SwitcherMode {
    case global
    case sameApp
}

/// Global event tap. Requires Accessibility permission (already mandatory
/// for window enumeration). All callbacks fire on the main thread.
final class HotKeyMonitor {
    /// Fired on every matching trigger press (first press opens the
    /// switcher; repeats advance the selection).
    var onTrigger: ((SwitcherMode) -> Void)?
    /// Raw flags on flagsChanged during an active session; the controller
    /// checks `modifiersStillHeld` against the shortcut that opened the
    /// session and commits when the modifiers are released.
    var onFlagsChanged: ((CGEventFlags) -> Void)?
    /// Fired when Escape is pressed during an active session.
    var onCancel: (() -> Void)?
    /// Queried to decide whether flagsChanged/Escape events matter and
    /// whether trigger keyDowns should be swallowed.
    var isSessionActive: () -> Bool = { false }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let preferences: Preferences

    init(preferences: Preferences = .shared) {
        self.preferences = preferences
    }

    func start() {
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            let monitor = Unmanaged<HotKeyMonitor>.fromOpaque(refcon!).takeUnretainedValue()
            return monitor.handle(type: type, event: event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            NSLog("MinimalTab: failed to create event tap (accessibility permission missing?)")
            return
        }
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS disables slow taps; re-enable and pass the event on.
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)

        case .keyDown:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags

            if preferences.globalShortcut.matches(keyCode: keyCode, flags: flags) {
                DispatchQueue.main.async { self.onTrigger?(.global) }
                return nil // swallow: the focused app must not receive it
            }
            if preferences.sameAppShortcut.matches(keyCode: keyCode, flags: flags) {
                DispatchQueue.main.async { self.onTrigger?(.sameApp) }
                return nil
            }
            if isSessionActive() && keyCode == 53 { // Escape
                DispatchQueue.main.async { self.onCancel?() }
                return nil
            }
            return Unmanaged.passUnretained(event)

        case .flagsChanged:
            guard isSessionActive() else { return Unmanaged.passUnretained(event) }
            // Both shortcuts share commit semantics: when the *active*
            // session's required modifiers stop being held, commit. The
            // controller knows which shortcut started the session.
            DispatchQueue.main.async { self.onFlagsChanged?(event.flags) }
            return Unmanaged.passUnretained(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: HotKeyMonitor event tap with trigger, release, and cancel callbacks"
```

---

### Task 10: SwitcherView — frosted-glass SwiftUI list

PRD §2.A (Apple-native aesthetic) and §2.B (icon + bold app name + regular title; minimized at 50% opacity).

**Files:**
- Create: `Sources/MinimalTab/UI/SwitcherView.swift`

- [ ] **Step 1: Write the implementation**

`Sources/MinimalTab/UI/SwitcherView.swift`:

```swift
import SwiftUI
import AppKit

/// Observable bridge between SwitcherController and SwiftUI.
@MainActor
final class SwitcherViewModel: ObservableObject {
    @Published var windows: [WindowInfo] = []
    @Published var selectedIndex: Int = 0
    /// Set by the view when the user clicks a row.
    var onRowClicked: ((Int) -> Void)?
}

/// NSVisualEffectView bridge for the frosted-glass background (PRD 2.A).
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct SwitcherView: View {
    @ObservedObject var model: SwitcherViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(Array(model.windows.enumerated()), id: \.element.id) { index, window in
                        SwitcherRow(window: window, isSelected: index == model.selectedIndex)
                            .id(index)
                            .onTapGesture { model.onRowClicked?(index) }
                    }
                }
                .padding(12)
            }
            .onChange(of: model.selectedIndex) { newIndex in
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
        .frame(width: 440)
        .frame(maxHeight: 480)
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}

private struct SwitcherRow: View {
    let window: WindowInfo
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            if let icon = window.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "macwindow")
                    .frame(width: 20, height: 20)
            }
            // PRD 2.B: [icon] + [bold app name] - [regular window title]
            Text(window.appName).fontWeight(.bold)
                + Text("  —  ").foregroundColor(.secondary)
                + Text(window.displayTitle)
            Spacer(minLength: 0)
        }
        .font(.system(size: 13))
        .lineLimit(1)
        .truncationMode(.middle)
        // PRD 4.A: minimized items at 50% text opacity
        .opacity(window.isMinimized ? 0.5 : 1.0)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            // PRD 2.A: rounded accent-color highlight on selection
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.85) : Color.clear)
        )
        .foregroundColor(isSelected ? .white : .primary)
        .contentShape(Rectangle())
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: frosted-glass SwitcherView with accent highlight and minimized dimming"
```

---

### Task 11: SwitcherPanel — non-activating panel centered on the mouse's screen

PRD §2.A (fade/scale spring animation) and §4.C (center of the display containing the cursor).

**Files:**
- Create: `Sources/MinimalTab/UI/SwitcherPanel.swift`

- [ ] **Step 1: Write the implementation**

`Sources/MinimalTab/UI/SwitcherPanel.swift`:

```swift
import AppKit
import SwiftUI

/// Borderless, non-activating floating panel. Non-activating is essential:
/// the user is holding a modifier over another app, and focus must not move
/// until they release it.
@MainActor
final class SwitcherPanel: NSPanel {
    private let hostingView: NSHostingView<SwitcherView>

    init(model: SwitcherViewModel) {
        hostingView = NSHostingView(rootView: SwitcherView(model: model))
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .transient]
        hidesOnDeactivate = false
        contentView = hostingView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// PRD 4.C: center on the screen containing the mouse cursor.
    /// PRD 2.A: fade-in with a light spring scale.
    func show() {
        hostingView.layoutSubtreeIfNeeded()
        let size = hostingView.fittingSize
        let screen = Self.screenUnderMouse()
        let frame = screen.visibleFrame
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2
        )
        setFrame(NSRect(origin: origin, size: size), display: true)

        alphaValue = 0
        contentView?.layer?.setAffineTransform(CGAffineTransform(scaleX: 0.97, y: 0.97))
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.0)
            animator().alphaValue = 1
            contentView?.layer?.setAffineTransform(.identity)
        }
    }

    func hide() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
        })
    }

    static func screenUnderMouse() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: non-activating switcher panel with mouse-screen centering and fade/scale animation"
```

---

### Task 12: SwitcherController — orchestrate session lifecycle

Ties Tasks 4, 7, 8, 9, 10, 11 together: trigger → enumerate+show / advance; release → commit; Escape → cancel.

**Files:**
- Create: `Sources/MinimalTab/UI/SwitcherController.swift`

- [ ] **Step 1: Write the implementation**

`Sources/MinimalTab/UI/SwitcherController.swift`:

```swift
import AppKit

/// Owns the live switcher session. One instance for the app's lifetime.
@MainActor
final class SwitcherController {
    private let enumerator = WindowEnumerator()
    private let activator = WindowActivator()
    private let preferences: Preferences
    private let viewModel = SwitcherViewModel()
    private lazy var panel = SwitcherPanel(model: viewModel)

    private var session: SwitcherSession?
    private var activeShortcut: KeyboardShortcut?

    var isActive: Bool { session != nil }

    init(preferences: Preferences = .shared) {
        self.preferences = preferences
        viewModel.onRowClicked = { [weak self] index in
            self?.session?.select(index: index)
            self?.commit()
        }
    }

    /// Called by HotKeyMonitor on every matching trigger keyDown.
    func handleTrigger(mode: SwitcherMode) {
        if session != nil {
            session?.advance()
            syncViewModel()
            return
        }
        begin(mode: mode)
    }

    /// Called by HotKeyMonitor on flagsChanged during an active session.
    func handleFlagsChanged(_ flags: CGEventFlags) {
        guard let shortcut = activeShortcut else { return }
        if !shortcut.modifiersStillHeld(flags: flags) {
            commit()
        }
    }

    func cancel() {
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
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: SwitcherController session orchestration"
```

---

### Task 13: Launch at login + Settings UI

PRD §3.B: shortcut customization, include-minimized toggle, launch-at-login, all persisted via `@AppStorage`/UserDefaults.

**Files:**
- Create: `Sources/MinimalTab/System/LaunchAtLogin.swift`
- Create: `Sources/MinimalTab/UI/ShortcutRecorderView.swift`
- Create: `Sources/MinimalTab/UI/SettingsView.swift`
- Create: `Sources/MinimalTab/UI/SettingsWindowController.swift`

- [ ] **Step 1: Write `Sources/MinimalTab/System/LaunchAtLogin.swift`**

```swift
import ServiceManagement

/// SMAppService only works when running from a real .app bundle
/// (dist/MinimalTab.app), not via `swift run`.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("MinimalTab: launch-at-login change failed: \(error)")
        }
    }
}
```

- [ ] **Step 2: Write `Sources/MinimalTab/UI/ShortcutRecorderView.swift`**

```swift
import SwiftUI
import AppKit

/// Click-to-record shortcut field. While recording, a local key monitor
/// captures the next modifier+key combination.
struct ShortcutRecorderView: View {
    let label: String
    @Binding var shortcut: KeyboardShortcut
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Button(action: toggleRecording) {
                Text(isRecording ? "키를 누르세요…" : shortcut.displayString)
                    .frame(minWidth: 90)
            }
        }
        .onDisappear { stopRecording() }
    }

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let mods = UInt64(event.modifierFlags.rawValue) & KeyboardShortcut.relevantModifierMask
            if event.keyCode == 53 && mods == 0 { // bare Escape cancels recording
                stopRecording()
                return nil
            }
            guard mods != 0 else { return nil } // require at least one modifier
            shortcut = KeyboardShortcut(keyCode: event.keyCode, modifiers: mods)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }
}
```

- [ ] **Step 3: Write `Sources/MinimalTab/UI/SettingsView.swift`**

```swift
import SwiftUI

struct SettingsView: View {
    // PRD 3.B: @AppStorage persistence; key shared with Preferences.
    @AppStorage(Preferences.Key.includeMinimized) private var includeMinimized = true
    @State private var globalShortcut = Preferences.shared.globalShortcut
    @State private var sameAppShortcut = Preferences.shared.sameAppShortcut
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            Section("단축키") {
                ShortcutRecorderView(label: "전체 윈도우 전환 (Global Switch)", shortcut: $globalShortcut)
                ShortcutRecorderView(label: "현재 앱 윈도우 전환 (Same-App Switch)", shortcut: $sameAppShortcut)
            }
            Section("목록") {
                Toggle("최소화된 윈도우 목록에 포함하기", isOn: $includeMinimized)
            }
            Section("일반") {
                Toggle("로그인 시 자동 실행 (Launch at login)", isOn: $launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: globalShortcut) { Preferences.shared.globalShortcut = $0 }
        .onChange(of: sameAppShortcut) { Preferences.shared.sameAppShortcut = $0 }
        .onChange(of: launchAtLogin) { LaunchAtLogin.set(enabled: $0) }
    }
}
```

- [ ] **Step 4: Write `Sources/MinimalTab/UI/SettingsWindowController.swift`**

```swift
import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    convenience init() {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "MinimalTab 설정"
        window.contentViewController = NSHostingController(rootView: SettingsView())
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }

    func show() {
        window?.center()
        // An LSUIElement app must explicitly activate to bring its
        // settings window forward.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
```

- [ ] **Step 5: Verify it compiles and tests still pass**

Run: `swift build && swift test`
Expected: `Build complete!`, all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: settings window with shortcut recorder, minimized toggle, launch at login"
```

---

### Task 14: Status bar, AppDelegate, and app bootstrap

PRD §3.A (menu bar icon with Settings…/Quit, no Dock icon) and final wiring.

**Files:**
- Create: `Sources/MinimalTab/UI/StatusBarController.swift`
- Create: `Sources/MinimalTab/AppDelegate.swift`
- Modify: `Sources/MinimalTab/main.swift` (replace placeholder)

- [ ] **Step 1: Write `Sources/MinimalTab/UI/StatusBarController.swift`**

```swift
import AppKit

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let onSettings: () -> Void

    init(onSettings: @escaping () -> Void) {
        self.onSettings = onSettings
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "rectangle.stack",
            accessibilityDescription: "MinimalTab"
        )

        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit MinimalTab", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func openSettings() {
        onSettings()
    }
}
```

- [ ] **Step 2: Write `Sources/MinimalTab/AppDelegate.swift`**

```swift
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?
    private var settingsWindow: SettingsWindowController?
    private var switcher: SwitcherController?
    private var hotKeys: HotKeyMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // PRD 3.A: menu-bar-only app, no Dock icon. (LSUIElement in
        // Info.plist covers the bundled app; this covers `swift run`.)
        NSApp.setActivationPolicy(.accessory)

        let settings = SettingsWindowController()
        settingsWindow = settings
        statusBar = StatusBarController(onSettings: { settings.show() })

        // PRD 4.D: check permission on launch, deep-link to System Settings.
        AccessibilityPermission.promptIfNeeded()

        let switcher = SwitcherController()
        self.switcher = switcher

        let hotKeys = HotKeyMonitor()
        hotKeys.isSessionActive = { switcher.isActive }
        hotKeys.onTrigger = { mode in switcher.handleTrigger(mode: mode) }
        hotKeys.onFlagsChanged = { flags in switcher.handleFlagsChanged(flags) }
        hotKeys.onCancel = { switcher.cancel() }
        hotKeys.start()
        self.hotKeys = hotKeys
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeys?.stop()
    }
}
```

- [ ] **Step 3: Replace `Sources/MinimalTab/main.swift`**

```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

- [ ] **Step 4: Verify full build and tests**

Run: `swift build && swift test`
Expected: `Build complete!`, all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: status bar menu, app delegate wiring, accessory activation"
```

---

### Task 15: Bundle, manual smoke test, README

**Files:**
- Create: `README.md`
- Create: `docs/smoke-test.md`

- [ ] **Step 1: Build the app bundle**

Run: `make app`
Expected: `Bundled: dist/MinimalTab.app`

- [ ] **Step 2: Write `docs/smoke-test.md`** (manual verification checklist for everything unit tests can't cover)

```markdown
# MinimalTab Manual Smoke Test

Run `make run` (or `open dist/MinimalTab.app`). After a rebuild, ad-hoc
signing changes, so re-grant Accessibility: System Settings > Privacy &
Security > Accessibility — remove and re-add (or toggle) MinimalTab.

## Permission (PRD 4.D)
- [ ] First launch without permission shows the Korean alert.
- [ ] "시스템 설정 열기" opens System Settings at Privacy & Security > Accessibility.
- [ ] After granting and relaunching, no alert appears.

## Menu bar (PRD 3.A)
- [ ] No Dock icon appears.
- [ ] Menu bar icon shows; menu contains "Settings…" and "Quit MinimalTab".
- [ ] Quit terminates the app.

## Global Switch (PRD 2.C)
- [ ] Hold Option, press Tab: panel appears centered on the screen under the cursor.
- [ ] Panel shows [icon] [bold app name] — [regular title] rows.
- [ ] Each Tab press (Option still held) advances the highlight; wraps at the end.
- [ ] Releasing Option activates the highlighted window and hides the panel.
- [ ] Escape while open cancels without switching.
- [ ] Clicking a row switches to it immediately.

## Same-App Switch (PRD 2.C)
- [ ] Open 2+ windows in one app (e.g. Safari). Option+` shows only that app's windows.
- [ ] Cycle and release works the same as Global Switch.

## Minimized/hidden handling (PRD 4.A)
- [ ] With "최소화된 윈도우 목록에 포함하기" ON: minimized windows appear dimmed (50%) with "(최소화됨)" suffix, listed last.
- [ ] Selecting a minimized window restores (unminimizes) and focuses it.
- [ ] Hide an app (Cmd+H): with the toggle ON its windows appear; selecting one unhides and focuses.
- [ ] With the toggle OFF: minimized and hidden windows do not appear at all.

## Untitled windows (PRD 4.B)
- [ ] A window with no title shows as "Untitled" (e.g. some utility windows).

## Multi-display (PRD 4.C)
- [ ] With 2 displays: panel appears centered on whichever display holds the mouse cursor.

## Settings (PRD 3.B)
- [ ] Settings window opens from the menu bar.
- [ ] Recording a new Global shortcut (e.g. ⌃Space) works immediately, persists across relaunch.
- [ ] Same for the Same-App shortcut.
- [ ] "로그인 시 자동 실행" toggle registers/unregisters (check System Settings > General > Login Items).

## No forbidden permissions (PRD 2.B)
- [ ] System Settings > Privacy & Security > Screen Recording does NOT list MinimalTab.
```

- [ ] **Step 3: Write `README.md`**

```markdown
# MinimalTab

A fast, text-only window switcher for macOS. No window previews, no screen
recording permission — just app names and window titles.

## Usage
- **Option + Tab** — switch between all windows (hold Option, tap Tab to cycle, release to switch)
- **Option + `** — switch between the current app's windows
- **Escape** — cancel
- Shortcuts are configurable from the menu bar icon → Settings…

## Requirements
- macOS 13+
- Accessibility permission (System Settings > Privacy & Security > Accessibility)

## Build
```sh
make test   # unit tests
make app    # builds dist/MinimalTab.app
make run    # build and launch
```

Note: the bundle is ad-hoc signed, so Accessibility permission must be
re-granted after each rebuild during development.
```

- [ ] **Step 4: Run the manual smoke test**

Run: `make run`, then walk through every checkbox in `docs/smoke-test.md`. Fix anything that fails before proceeding (use the systematic-debugging skill for failures).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "docs: README and manual smoke-test checklist"
```

---

## Spec Coverage Self-Review

| PRD requirement | Task |
|---|---|
| 2.A frosted glass, SF Pro hierarchy, rounded corners, accent highlight | Task 10 |
| 2.A fade/scale spring animation | Task 11 |
| 2.B no screen capture; icon + bold app + regular title rows | Tasks 7, 10 |
| 2.C Global Switch / Same-App Switch | Tasks 7, 9, 12 |
| 2.C hold-modifier, cycle on trigger, commit on release | Tasks 4, 9, 12 |
| 3.A menu bar only, Settings…/Quit menu, no Dock icon | Tasks 1 (LSUIElement), 14 |
| 3.B @AppStorage persistence, shortcut customization, minimized toggle, launch at login | Tasks 5, 13 |
| 4.A minimized/hidden: 50% opacity + (최소화됨) suffix, restore on select, full exclusion when off | Tasks 2, 8, 10 |
| 4.B Untitled fallback | Task 2 |
| 4.C panel centered on mouse's display | Task 11 |
| 4.D permission check + System Settings deep link on launch | Tasks 6, 14 |
