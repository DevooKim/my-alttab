.PHONY: build test app run release

VERSION := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)

build:
	swift build

test:
	swift run minimaltab-tests

app:
	bash scripts/bundle.sh

run: app
	open "dist/My AltTab.app"

# ditto preserves symlinks, extended attributes, and the code signature —
# required for distributing .app bundles.
release: app
	ditto -c -k --keepParent "dist/My AltTab.app" "dist/My-AltTab-v$(VERSION).zip"
	@echo "Created: dist/My-AltTab-v$(VERSION).zip"
