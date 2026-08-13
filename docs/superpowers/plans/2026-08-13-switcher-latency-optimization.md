# Switcher Latency Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove trigger-time Accessibility IPC from the main actor and eliminate repeated MRU, Space-membership, and per-app metadata work without changing switcher behavior.

**Architecture:** The controller starts one detached load immediately, resolves the focused window there, and briefly returns to the main actor only to apply the existing MRU guard and capture an immutable rank table. Window enumeration then continues off-main using that table and one shared Space-membership map. Cancellation remains token-based at both the preparation and completion actor hops.

**Tech Stack:** Swift 5 language mode, Swift Package Manager, AppKit, ApplicationServices, Swift concurrency, the repository's executable test harness, macOS `sample`.

---

### Task 1: Constant-Time MRU Rank Snapshot

**Files:**
- Modify: `Sources/MinimalTabCore/System/MRUTracker.swift`
- Create: `Tests/MinimalTabTests/MRUTrackerTests.swift`
- Modify: `Tests/MinimalTabTests/main.swift`

- [ ] **Step 1: Write the failing rank snapshot tests**

Add `runMRUTrackerTests()` with an ordered `[CGWindowID]`, assertions for all
known ranks, zero and unknown IDs, and an assertion that changing the source
array after initialization does not change the snapshot. Register the suite in
`main.swift`.

```swift
import CoreGraphics
import MinimalTabCore

func runMRUTrackerTests() {
    var source: [CGWindowID] = [42, 7, 99]
    let snapshot = MRURankSnapshot(windowIDs: source)

    expectEqual(snapshot.rank(of: 42), 0, "first MRU window has rank zero")
    expectEqual(snapshot.rank(of: 7), 1, "second MRU window has rank one")
    expectEqual(snapshot.rank(of: 99), 2, "third MRU window has rank two")
    expect(snapshot.rank(of: 0) == nil, "zero window ID is never ranked")
    expect(snapshot.rank(of: 123) == nil, "unknown window ID is not ranked")

    source.insert(123, at: 0)
    expectEqual(snapshot.rank(of: 42), 0, "snapshot is immutable after source changes")
    expect(snapshot.rank(of: 123) == nil, "snapshot does not observe later source changes")
}
```

- [ ] **Step 2: Run tests to verify RED**

Run: `make test`

Expected: compilation fails because `MRURankSnapshot` is not defined.

- [ ] **Step 3: Implement the immutable dictionary snapshot**

Add the value type next to `MRUTracker`, then return it from
`rankSnapshot()`.

```swift
public struct MRURankSnapshot: Sendable {
    private let ranks: [CGWindowID: Int]

    public init(windowIDs: [CGWindowID]) {
        self.ranks = Dictionary(
            uniqueKeysWithValues: windowIDs.enumerated().map { ($0.element, $0.offset) }
        )
    }

    public func rank(of windowID: CGWindowID) -> Int? {
        guard windowID != 0 else { return nil }
        return ranks[windowID]
    }
}
```

Replace the closure-producing snapshot with:

```swift
public func rankSnapshot() -> MRURankSnapshot {
    MRURankSnapshot(windowIDs: windowIDs)
}
```

- [ ] **Step 4: Run tests to verify GREEN**

Run: `make test`

Expected: `113 passed, 0 failed`.

- [ ] **Step 5: Commit the focused change**

```bash
git add Sources/MinimalTabCore/System/MRUTracker.swift \
  Tests/MinimalTabTests/MRUTrackerTests.swift Tests/MinimalTabTests/main.swift
git commit -m "성능: MRU 순위 조회를 상수 시간으로 개선"
```

### Task 2: Off-Main Focus Refresh and Enumeration Reuse

**Files:**
- Modify: `Sources/MinimalTabCore/System/MRUTracker.swift`
- Modify: `Sources/MinimalTabCore/System/WindowEnumerator.swift`
- Modify: `Sources/MinimalTabCore/UI/SwitcherController.swift`

- [ ] **Step 1: Record the current regression evidence**

Keep `/tmp/my-alttab-trigger.sample` as the baseline diagnostic. Confirm it
contains this main-thread chain:

```text
SwitcherController.begin(mode:openingAction:)
MRUTracker.focusedWindowID(of:)
AXUIElementCopyAttributeValue
mach_msg2_trap
```

Run:

```bash
rg -n "SwitcherController.begin|MRUTracker.focusedWindowID|AXUIElementCopyAttributeValue" \
  /tmp/my-alttab-trigger.sample
```

Expected: all three symbols appear in the main-thread call graph.

- [ ] **Step 2: Make the stateless AX lookup callable off-actor**

Mark the method as nonisolated; do not change its timeout or fallback.

```swift
public nonisolated static func focusedWindowID(of pid: pid_t) -> CGWindowID? {
```

- [ ] **Step 3: Move focus refresh into the detached load**

In `SwitcherController.begin`, capture only the frontmost PID on the main
actor. Remove the synchronous focused-window lookup and the pre-task rank
snapshot. At the start of the detached task, resolve the focused window, then
use a guarded main-actor hop to touch MRU and capture the snapshot.

```swift
let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

Task.detached(priority: .userInitiated) {
    let focusedWindowID = frontmostPID.flatMap { MRUTracker.focusedWindowID(of: $0) }
    guard let rank = await MainActor.run(body: { [weak self] () -> MRURankSnapshot? in
        guard let self, token == self.loadToken, self.isLoading else { return nil }
        if let focusedWindowID {
            self.mru.touch(focusedWindowID, source: .activation)
        }
        return self.mru.rankSnapshot()
    }) else { return }

    let mruRank: (WindowInfo) -> Int? = { rank.rank(of: $0.windowID) }
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
```

This preserves the existing commit guard because `touch` still receives
`.activation`, and it avoids enumeration if cancellation invalidates the token
during the AX request.

- [ ] **Step 4: Reuse Space membership and app metadata**

Pass the existing `spaceByWindowID` map into `inactiveSpaceWindows` and remove
its second `allSpaceWindowIDs` conversion. In `windowsOf`, read app-level
properties once before `compactMap`.

```swift
private func inactiveSpaceWindows(
    alreadyFound: [WindowInfo],
    spaceByWindowID: [CGWindowID: Int],
    blacklist: [String]
) -> [WindowInfo] {
    let knownIDs = Set(alreadyFound.map(\.windowID))
}
```

Call it with the existing map:

```swift
if showAllSpaces {
    windows.append(contentsOf: inactiveSpaceWindows(
        alreadyFound: windows,
        spaceByWindowID: spaceByWindowID,
        blacklist: blacklist
    ))
}
```

Inside the inactive-window guard, replace the rebuilt map lookup with:

```swift
let space = spaceByWindowID[widValue]
```

```swift
let appName = app.localizedName ?? "Unknown"
let appIcon = app.icon
let isHidden = app.isHidden
```

Use `appIcon` and `isHidden` for each `WindowInfo` produced by that app.

- [ ] **Step 5: Run the complete test suite**

Run: `make test`

Expected: `113 passed, 0 failed`.

- [ ] **Step 6: Commit the latency optimization**

```bash
git add Sources/MinimalTabCore/System/MRUTracker.swift \
  Sources/MinimalTabCore/System/WindowEnumerator.swift \
  Sources/MinimalTabCore/UI/SwitcherController.swift
git commit -m "성능: 스위처 실행 경로의 메인 스레드 대기 제거"
```

### Task 3: Build and Runtime Verification

**Files:**
- Verify: `docs/smoke-test.md`
- Verify: `dist/My AltTab.app`

- [ ] **Step 1: Build the release bundle**

Run: `make app`

Expected: release build succeeds, the bundle is signed, and
`dist/My AltTab.app` is created.

- [ ] **Step 2: Launch the built app and run automated smoke input**

Stop the currently running 0.7.7 process, open the built bundle, and use trusted
CGEvents to exercise open, cycle, Escape cancellation, reverse opening, and
modifier release. Confirm the process remains alive after each flow.

- [ ] **Step 3: Capture the optimized trigger path**

Run `sample` while repeatedly opening and cancelling the switcher. Inspect the
main-thread subtree and all occurrences of `focusedWindowID`.

Expected:

- `MRUTracker.focusedWindowID(of:)` appears under the detached
  user-initiated task when captured.
- It does not appear below the main-thread
  `SwitcherController.handleTrigger`/`begin` chain.
- The process returns to 0% idle CPU after the flow.

- [ ] **Step 4: Restore the installed app**

Terminate the test bundle and reopen `/Applications/My AltTab.app` so the
developer build is not left running as the user's daily app.

- [ ] **Step 5: Inspect scope and request code review**

Run `git status -sb`, `git diff origin/main...HEAD`, and `git diff --check`.
Request a focused code review against `origin/main`, fix all Critical and
Important findings with RED→GREEN coverage where behavior changes.

### Task 4: Publish Draft PR

**Files:**
- Verify: entire branch diff

- [ ] **Step 1: Run final gates**

Run:

```bash
make test
make app
git diff --check origin/main...HEAD
```

Expected: tests and build pass with no whitespace errors.

- [ ] **Step 2: Commit any remaining plan or review changes**

Stage only files belonging to this optimization and use a separate Korean
commit. Do not amend earlier commits.

- [ ] **Step 3: Push the branch**

Run:

```bash
git push -u origin agent/optimize-switcher-latency
```

- [ ] **Step 4: Open a Draft PR**

Target `DevooKim/my-alttab:main`. The PR body must explain the measured
main-thread AX wait, the preserved MRU/cancellation behavior, the reduced
repeated work, and the exact test/build/runtime checks.
