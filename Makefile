# VaultBreak macOS — local build helpers (XcodeGen + xcodebuild)
SCHEME      ?= VaultBreak
DESTINATION ?= platform=macOS
XCODEBUILD  ?= xcodebuild
XCODEGEN    ?= xcodegen

.PHONY: help generate build test preflight clean open

help:
	@echo "Targets:"
	@echo "  make generate  — regenerate VaultBreak.xcodeproj from project.yml"
	@echo "  make build     — generate + build (Debug)"
	@echo "  make test      — generate + run unit tests"
	@echo "  make preflight — run tests, archive ReleaseMAS, and smoke-test production"
	@echo "  make open      — generate + open in Xcode"
	@echo "  make clean     — remove generated project"

generate:
	@command -v $(XCODEGEN) >/dev/null || { \
	  echo "error: xcodegen not found. Install with: brew install xcodegen" >&2; \
	  exit 1; \
	}
	$(XCODEGEN) generate

build: generate
	$(XCODEBUILD) -scheme $(SCHEME) -destination '$(DESTINATION)' -quiet build

test: generate
	$(XCODEBUILD) -scheme $(SCHEME) -destination '$(DESTINATION)' test

preflight: generate
	./scripts/app-store-preflight.sh

open: generate
	open VaultBreak.xcodeproj

clean:
	rm -rf VaultBreak.xcodeproj
