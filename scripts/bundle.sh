#!/bin/bash
# Assembles dist/MinimalTab.app from the SPM release binary.
# Signs with the "My AltTab Dev" self-signed identity when present, so the
# code signature (and therefore the TCC Accessibility grant) stays stable
# across rebuilds. Falls back to ad-hoc signing, which requires re-granting
# permission after every build.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="dist/My AltTab.app"
rm -rf "$APP" dist/MinimalTab.app
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp .build/release/MinimalTab "$APP/Contents/MacOS/MinimalTab"

# UI strings are hardcoded (see L10n.swift) — no SPM resource bundle, so the
# app is a single self-contained executable with no nested code. This is
# deliberate: a nested resource bundle was signed as nested code pinned to the
# self-signed cert, which made macOS reject the app on other Macs.

IDENTITY="My AltTab Dev"
if security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
    SIGN=(--sign "$IDENTITY")
else
    echo "warning: '$IDENTITY' identity not found; ad-hoc signing (permission must be re-granted each build)" >&2
    SIGN=(--sign -)
fi
# No --deep needed: nothing nested to sign.
codesign --force "${SIGN[@]}" "$APP"
echo "Bundled: $APP"
