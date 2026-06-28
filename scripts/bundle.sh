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

# SPM puts localized resources in a sibling bundle. It is DATA, so it must
# live in Contents/Resources — NOT Contents/MacOS. In Contents/MacOS codesign
# treats it as *nested code* and pins it to the self-signed leaf certificate;
# Macs without that cert then fail nested-code validation and AMFI kills the
# app at launch (silent: no icon, no crash). Bundle.module for an SPM
# executableTarget looks next to the executable (Contents/MacOS), so place a
# relative symlink there pointing at the real bundle in Resources — a symlink
# is sealed as a resource, not as nested code.
RES_BUNDLE="MinimalTab_MinimalTabCore.bundle"
if [ -d ".build/release/$RES_BUNDLE" ]; then
    cp -R ".build/release/$RES_BUNDLE" "$APP/Contents/Resources/$RES_BUNDLE"
    ln -s "../Resources/$RES_BUNDLE" "$APP/Contents/MacOS/$RES_BUNDLE"
else
    echo "warning: $RES_BUNDLE not found — localization will fall back to keys" >&2
fi

IDENTITY="My AltTab Dev"
if security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
    SIGN=(--sign "$IDENTITY")
else
    echo "warning: '$IDENTITY' identity not found; ad-hoc signing (permission must be re-granted each build)" >&2
    SIGN=(--sign -)
fi
# Sign inside-out (Apple deprecated --deep). Sign the resource bundle first,
# then the outer app — which now seals the bundle as a plain resource (hash
# only, no cert-pinned requirement), so it launches on Macs without our cert.
if [ -d "$APP/Contents/Resources/$RES_BUNDLE" ]; then
    codesign --force "${SIGN[@]}" "$APP/Contents/Resources/$RES_BUNDLE"
fi
codesign --force "${SIGN[@]}" "$APP"
echo "Bundled: $APP"
