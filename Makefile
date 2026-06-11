.PHONY: build test app run

build:
	swift build

test:
	swift run minimaltab-tests

app:
	bash scripts/bundle.sh

run: app
	open "dist/My AltTab.app"
