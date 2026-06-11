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
make test   # unit tests (swift run minimaltab-tests — XCTest needs Xcode, which isn't required here)
make app    # builds dist/MinimalTab.app
make run    # build and launch
```

Note: the bundle is ad-hoc signed, so Accessibility permission must be
re-granted after each rebuild during development (toggle the MinimalTab
entry off/on in System Settings).

## Manual verification

See [docs/smoke-test.md](docs/smoke-test.md) for the full checklist covering
behavior that unit tests can't reach (hotkeys, panel, permissions).
