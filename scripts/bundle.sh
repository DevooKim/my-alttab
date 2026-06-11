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
