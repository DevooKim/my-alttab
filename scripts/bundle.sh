#!/bin/bash
# Assembles dist/MinimalTab.app from the SPM release binary.
# Signs with the "MinimalTab Dev" self-signed identity when present, so the
# code signature (and therefore the TCC Accessibility grant) stays stable
# across rebuilds. Falls back to ad-hoc signing, which requires re-granting
# permission after every build.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="dist/My AltTab.app"
rm -rf "$APP" dist/MinimalTab.app
mkdir -p "$APP/Contents/MacOS"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp .build/release/MinimalTab "$APP/Contents/MacOS/MinimalTab"

IDENTITY="MinimalTab Dev"
if security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
    codesign --force --sign "$IDENTITY" "$APP"
else
    echo "warning: '$IDENTITY' identity not found; ad-hoc signing (permission must be re-granted each build)" >&2
    codesign --force --sign - "$APP"
fi
echo "Bundled: $APP"
