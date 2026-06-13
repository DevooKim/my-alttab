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

# SPM puts localized resources in a sibling bundle; Bundle.module looks for
# it next to the executable, so copy it into Contents/MacOS.
RES_BUNDLE="MinimalTab_MinimalTabCore.bundle"
if [ -d ".build/release/$RES_BUNDLE" ]; then
    cp -R ".build/release/$RES_BUNDLE" "$APP/Contents/MacOS/$RES_BUNDLE"
else
    echo "warning: $RES_BUNDLE not found — localization will fall back to keys" >&2
fi

IDENTITY="My AltTab Dev"
# --deep so the nested resource bundle (MinimalTab_MinimalTabCore.bundle)
# is signed too; an unsigned nested bundle fails the outer signature.
if security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
    codesign --force --deep --sign "$IDENTITY" "$APP"
else
    echo "warning: '$IDENTITY' identity not found; ad-hoc signing (permission must be re-granted each build)" >&2
    codesign --force --deep --sign - "$APP"
fi
echo "Bundled: $APP"
