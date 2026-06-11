.PHONY: build test app run release publish

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
# release. Bump CFBundleShortVersionString in Resources/Info.plist first.
publish: test release
	@if ! git diff-index --quiet HEAD --; then \
		echo "error: uncommitted changes — commit before publishing" >&2; exit 1; \
	fi
	@if git rev-parse "v$(VERSION)" >/dev/null 2>&1; then \
		echo "error: tag v$(VERSION) already exists — bump the version in Resources/Info.plist" >&2; exit 1; \
	fi
	git tag "v$(VERSION)"
	git push origin main "v$(VERSION)"
	gh release create "v$(VERSION)" "dist/My-AltTab-v$(VERSION).zip" \
		--title "My AltTab v$(VERSION)" \
		--generate-notes \
		--notes "**Install:** unzip, move \`My AltTab.app\` to Applications, open via System Settings > Privacy & Security (\"Open Anyway\"), then grant Accessibility permission. See the [README](README.md#install) / [한국어 안내](README.ko.md#설치)."
	@echo "Published: v$(VERSION)"
