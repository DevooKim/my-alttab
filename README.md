# My AltTab

A fast, text-only window switcher for macOS. No window previews, no screen
recording permission — just app names and window titles.

## Usage
- **Option + Tab** — switch between all windows (hold Option, tap Tab to cycle, release to switch)
- **Option + `** — switch between the current app's windows
- **Escape** — cancel
- Shortcuts are configurable from the menu bar icon → Settings…

## Install

1. Download the latest `My-AltTab-vX.Y.Z.zip` from [Releases](../../releases) and unzip it.
2. Move `My AltTab.app` to your Applications folder and open it.
3. **First launch:** macOS will block the app (it is not notarized). Go to
   System Settings > Privacy & Security and click **"Open Anyway"**, then
   confirm.
4. Grant Accessibility permission when prompted (System Settings >
   Privacy & Security > Accessibility) and relaunch the app.

## Requirements
- macOS 13+
- Accessibility permission (System Settings > Privacy & Security > Accessibility)

## Build

```sh
make test   # unit tests (swift run minimaltab-tests — XCTest needs Xcode, which isn't required here)
make app    # builds "dist/My AltTab.app"
make run    # build and launch
```

Note: the bundle is ad-hoc signed, so Accessibility permission must be
re-granted after each rebuild during development (toggle the MinimalTab
entry off/on in System Settings).

## Manual verification

See [docs/smoke-test.md](docs/smoke-test.md) for the full checklist covering
behavior that unit tests can't reach (hotkeys, panel, permissions).
