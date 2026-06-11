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
