.PHONY: help build test bundle release open install update dist publish lab demo clean

help:             ## Show the targets
	@grep -E '^[a-z]+:.*## ' Makefile | awk -F':.*## ' '{printf "  make %-9s %s\n", $$1, $$2}'

build:            ## Debug build (SwiftPM)
	swift build --product ASOWorkbench

test:             ## Unit tests (live Apple tests are opt-in, see Tests/)
	swift test --skip Live

bundle:           ## Debug build/ASO Workbench.app
	scripts/bundle-app.sh debug

release:          ## Optimized build/ASO Workbench.app
	scripts/bundle-app.sh release

open: bundle      ## Build and launch
	open "build/ASO Workbench.app"

install: release  ## Optimized build copied to /Applications
	rm -rf "/Applications/ASO Workbench.app"
	cp -R "build/ASO Workbench.app" /Applications/
	@echo "→ /Applications/ASO Workbench.app"

update:           ## Pull the latest source and reinstall
	git pull --ff-only
	$(MAKE) install

dist:             ## Release .dmg + .zip + checksums + notes in dist/ (maintainers)
	scripts/release.sh

publish:          ## dist + create the GitHub release with gh (maintainers)
	scripts/release.sh --publish

lab: bundle       ## Launch with the developer Lab (model training, URL commands)
	open --env ASO_LAB=1 "build/ASO Workbench.app"

demo:             ## README demo from a screen recording: make demo VIDEO="path/to/recording.mov"
	scripts/make-demo.sh "$(VIDEO)"

xcode:            ## Open the package in Xcode
	open Package.swift

clean:
	rm -rf .build build dist
