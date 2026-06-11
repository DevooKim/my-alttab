.PHONY: build test app run release publish bump-patch bump-minor bump-major

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

# Tests, builds the zip, tags v$(VERSION), pushes, and publishes a GitHub
# release with a commit-based changelog (see scripts/publish.sh).
# Bump CFBundleShortVersionString in Resources/Info.plist first.
publish: test release
	@bash scripts/publish.sh

# Bump CFBundleShortVersionString (semver) and CFBundleVersion (build
# number), then commit. Release flow: make bump-minor && make publish
bump-patch:
	@bash scripts/bump.sh patch

bump-minor:
	@bash scripts/bump.sh minor

bump-major:
	@bash scripts/bump.sh major
