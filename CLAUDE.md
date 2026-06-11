# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"My AltTab" — a text-only macOS window switcher (no previews, no Screen Recording permission). User-facing name is **My AltTab**; internal target/module/binary names remain **MinimalTab**. UI strings are Korean. READMEs are bilingual (README.md English, README.ko.md Korean) — update both.

## Commands

```sh
make test     # run unit tests
make app      # build "dist/My AltTab.app" (release) via scripts/bundle.sh
make run      # build, bundle, and launch
make release  # build the distributable zip (ditto, preserves signature)
make publish  # test + zip + tag v$(VERSION) + push + GitHub release (gh CLI)
make bump-patch|bump-minor|bump-major  # bump Info.plist version + commit
```

Release flow: `make bump-minor && make publish`. The version's single source of truth is `Resources/Info.plist` (`CFBundleShortVersionString` + `CFBundleVersion` build number).

**No Xcode on this machine — Command Line Tools only.** XCTest and Swift Testing are unavailable. Tests are an executable target (`Tests/MinimalTabTests`) with a tiny assert harness (`TestKit.swift`): each suite is a `runXxxTests()` function registered in `Tests/MinimalTabTests/main.swift`, executed by `swift run minimaltab-tests`. There is no single-test runner; comment out suite calls in `main.swift` to narrow a run.

To restart the app after changes: `make app && pkill -f "Contents/MacOS/MinimalTab"; open "dist/My AltTab.app"`.

## Architecture

Three SPM targets: `MinimalTabCore` (library — all code), `MinimalTab` (thin executable, just `main.swift` bootstrapping `AppDelegate`), `minimaltab-tests` (test runner). The library split exists solely so the test runner can import the code; tested types are `public`.

Within `Sources/MinimalTabCore`:
- **Models/** — pure logic, no system dependencies, fully unit-tested: `WindowInfo` (display-title fallback, visibility filtering), `KeyboardShortcut` (event matching incl. standalone-modifier mapping), `SwitcherSession` (selection cycling/removal state machine). `WindowInfo.axElement` is optional so tests construct instances without AX.
- **System/** — thin wrappers around macOS APIs, verified manually: `WindowEnumerator`, `WindowActivator`, `HotKeyMonitor` (CGEventTap), `MRUTracker`, `AccessibilityPermission`, `LaunchAtLogin`.
- **UI/** — `SwitcherController` (session orchestration; the hub wiring everything), `SwitcherPanel` (non-activating NSPanel), `SwitcherView` (SwiftUI), settings UI.

Event flow: `HotKeyMonitor`'s CGEventTap (main run loop) fires closures wired in `AppDelegate` → `SwitcherController` owns the `SwitcherSession`, the panel, and the `MRUTracker`. Trigger keyDowns are swallowed (return nil) so the focused app never sees them; commit happens when `flagsChanged` shows the session's required modifiers released.

## Critical constraints

- **Never read `kCGWindowName`** — it silently requires Screen Recording permission, which this app must never request. Window titles come from AX (`kAXTitleAttribute`); `CGWindowListCopyWindowInfo` is used only for PID z-ordering (permission-free).
- **Do not change `CFBundleIdentifier` (`io.goorm.minimaltab`) or the signing identity ("MinimalTab Dev", a self-signed cert in the login keychain).** TCC ties the Accessibility grant to bundle ID + certificate; changing either forces users to re-grant permission. `scripts/bundle.sh` falls back to ad-hoc signing if the identity is missing (then permission must be re-granted every build).
- **Modifier keys (Shift, Control, …) never produce keyDown events** — only `flagsChanged`. Any "press a key" feature must handle both paths (see `KeyboardShortcut.modifierFlag(for:)` and the dual handling in `HotKeyMonitor`/`SingleKeyRecorderView`).
- `ShortcutCapture.isRecording` suspends the event tap's keyDown matching while a settings recorder is active — without it the tap swallows the very keys being recorded.
- The switcher panel must stay non-activating (`canBecomeKey` false); stealing focus mid-session breaks the hold-modifier interaction.
- Swift language mode 5 (tools 5.10) is deliberate — strict Swift 6 concurrency fights the C callback (CGEventTap) and AX APIs.

## Verification

System-API behavior (hotkeys, panel, permission flows, multi-display) can't be unit-tested; walk `docs/smoke-test.md` after touching System/ or UI/ code. The implementation plan with PRD coverage lives in `docs/superpowers/plans/2026-06-11-minimaltab.md`.
