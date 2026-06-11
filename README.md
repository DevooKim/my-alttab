# My AltTab

[한국어](README.ko.md)

A fast, text-only window switcher for macOS. No window previews, no screen
recording permission — just app names and window titles.

## Features

- **Option + Tab** — switch between all windows (hold Option, tap Tab to cycle, release to switch)
- **Option + `** — switch between the current app's windows only
- **MRU ordering** — windows are listed by most-recently-used, so a single
  trigger press toggles between your two latest windows
- **Quick Actions** — while the list is open: `W` closes the selected
  window, `Q` quits its app
- **Reverse navigation** — `←` moves the selection backward
- **Settings key** — `,` opens settings while the list is open
- **App exclusion list** — remote-desktop/VM viewers are excluded by
  default (AltTab's list); add or remove apps in Settings
- Minimized windows shown dimmed with a suffix (toggleable), untitled
  windows fall back to "Untitled", panel appears on the display under
  your cursor
- All keys are configurable from the menu bar icon → Settings…

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

## Build from source

```sh
make test     # unit tests (swift run minimaltab-tests — no Xcode required)
make app      # builds "dist/My AltTab.app"
make run      # build and launch
make release  # builds the distributable zip
```

Note: locally built bundles are signed with a self-signed identity
("MinimalTab Dev"), so Accessibility permission must be granted once per
identity. See [docs/smoke-test.md](docs/smoke-test.md) for the manual
verification checklist.
