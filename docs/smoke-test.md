# My AltTab Manual Smoke Test

Run `make run` (or `open "dist/My AltTab.app"`). The bundle is signed with
the stable "My AltTab Dev" identity, so the Accessibility grant persists
across rebuilds. If it ever gets lost: System Settings > Privacy & Security
> Accessibility — remove and re-add My AltTab.

## First-run onboarding
- [ ] On first launch (reset: `defaults delete io.goorm.minimaltab hasCompletedOnboarding`), the onboarding window appears and the standalone permission alert does NOT.
- [ ] Onboarding shows app icon, shortcut guide, and an Accessibility status row.
- [ ] When permission is missing the row shows ⚠️ + a "권한 허용" button; granting it (in System Settings) flips the row to ✓ live, without relaunch.
- [ ] "시작하기" closes the window; relaunching does NOT show onboarding again.
- [ ] On later launches without permission, the usual alert appears (not onboarding).

## Permission
- [ ] "시스템 설정 열기" opens System Settings at Privacy & Security > Accessibility.
- [ ] Granting permission while running starts the event tap without a manual restart (retry timer).

## Menu bar
- [ ] No Dock icon appears.
- [ ] Menu bar icon shows; menu contains "My AltTab 정보", "업데이트 확인…", "Settings…", "Quit My AltTab".
- [ ] Quit terminates the app.

## Global Switch
- [ ] Hold Option, press Tab: panel appears centered on the screen under the cursor.
- [ ] Panel shows [icon] [bold app name] — [regular title] rows, MRU-ordered.
- [ ] Each Tab press (Option still held) advances the highlight; wraps at the end.
- [ ] Holding Shift (default reverse key) moves the selection backward.
- [ ] Releasing Option activates the highlighted window and hides the panel.
- [ ] Pressing the trigger once and releasing toggles between the two most-recent windows.
- [ ] Escape while open cancels without switching.
- [ ] Clicking a row switches to it immediately.

## Same-App Switch
- [ ] Open 2+ windows in one app (e.g. Safari). Option+` shows only that app's windows.
- [ ] Cycle and release works the same as Global Switch.

## Empty state
- [ ] When no switchable windows exist (e.g. everything blacklisted), Option+Tab shows a "전환할 창이 없습니다" panel.
- [ ] The empty panel closes on modifier release, on Escape, or automatically after ~2 seconds.

## Quick Actions (list open)
- [ ] Pressing W closes the selected window (app may prompt to save); the list stays open and selection moves on.
- [ ] Pressing Q quits the selected window's app; its windows leave the list.
- [ ] Pressing , opens Settings (and closes the switcher).
- [ ] All Quick Action keys are configurable in Settings and accept modifier keys.

## Minimized/hidden handling
- [ ] With "최소화된 윈도우 목록에 포함하기" ON: minimized windows appear dimmed (50%) with "(최소화됨)" suffix, listed last.
- [ ] Selecting a minimized window restores (unminimizes) and focuses it.
- [ ] Hide an app (Cmd+H): with the toggle ON its windows appear; selecting one unhides and focuses.
- [ ] With the toggle OFF: minimized and hidden windows do not appear at all.

## Untitled windows
- [ ] A window with no title shows as "Untitled".

## Spaces
- [ ] Each row shows its Space (desktop) number badge at the trailing edge.
- [ ] With "모든 Space의 창 표시" OFF: only the active Space's windows appear; no Screen Recording prompt.
- [ ] Turning it ON prompts for Screen Recording, then the app auto-relaunches once granted.
- [ ] After granting: windows from inactive Spaces appear with titles; selecting one switches to that Space and focuses it.

## Multi-display
- [ ] With 2 displays: panel appears centered on whichever display holds the mouse cursor.

## Settings
- [ ] Settings window opens from the menu bar and always starts on the 일반 tab.
- [ ] Tabs: 일반 / UI / 정보.
- [ ] Recording a new Global shortcut (e.g. ⌃Space) works immediately, persists across relaunch.
- [ ] Same for the Same-App shortcut. Modifier-only keys (e.g. ⇧) can be recorded.
- [ ] UI tab: list size (작게/중간/크게) and highlight style (전체 채우기/테두리만) apply on next open.
- [ ] Exclusion list: default apps shown; add a running app, "제거", and "기본값 복원" work. The list area scrolls independently.
- [ ] "로그인 시 자동 실행" toggle registers/unregisters (check System Settings > General > Login Items).
- [ ] Cmd+W closes the Settings window; Cmd+Q quits the app.

## Auto-update
- [ ] "업데이트 확인…" (menu bar or 정보 tab) reports "최신 버전입니다" when up to date.
- [ ] To test the update path: lower the dist bundle's CFBundleShortVersionString, re-sign (`codesign --force --sign "My AltTab Dev"`), relaunch → "업데이트 확인" detects the newer GitHub release, downloads, de-quarantines, swaps, and relaunches. Restore with `make app`.

## Forbidden permission gate
- [ ] With "모든 Space의 창 표시" OFF, System Settings > Privacy & Security > Screen Recording does NOT require My AltTab (kCGWindowName is never touched).
