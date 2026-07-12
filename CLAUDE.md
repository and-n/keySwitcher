# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project setup

- The Xcode project is **generated**: `project.yml` is the source of truth, `keySwitcher.xcodeproj` is gitignored. After editing `project.yml`, run `xcodegen generate`. Never `git add` the `.xcodeproj`.
- No external dependencies by design — system frameworks only.

## Build, run, test

```sh
xcodegen generate                    # required once and after project.yml changes
xcodebuild -scheme keySwitcher -configuration Debug -derivedDataPath build build
pkill -x keySwitcher; open build/Build/Products/Debug/keySwitcher.app
xcodebuild -scheme keySwitcher -derivedDataPath build test
```

- Single-file SourceKit diagnostics ("Cannot find type … in scope") are noise in this repo — the editor indexes files without project context. Trust `xcodebuild` output only.
- The app cannot be exercised from the shell: no synthetic keystrokes, no screenshots. Test logic through XCTest (`keySwitcherTests/`); verify UI changes by rebuilding and asking the user to look.
- Conversion tests require the ABC and Russian keyboard layouts installed; they skip themselves otherwise.

## Gotchas

- macOS ties the Accessibility (TCC) grant to the app's code signature. If the running app shows the onboarding window despite the System Settings checkbox, the entry is stale: it must be removed (minus button) and re-granted — toggling is not enough. Release builds are ad-hoc signed until a Developer ID exists, so every released update loses the grant; this is expected, not a bug.
- The app is `LSUIElement` (menu bar only): no Dock icon, and the SwiftUI `Settings` scene is a stub — the real settings window is opened from the status bar menu via `AppDelegate.showSettings()`.
- Keystrokes must stay in memory only (`KeyBuffer`), never written to disk or logs — this is a core privacy promise (see README).
- The app icon is generated: edit `scripts/generate_icon.swift` and run `swift scripts/generate_icon.swift` from the repo root. Never hand-edit the PNGs in `AppIcon.appiconset`.

## Releases

- Pushing a `v*` tag triggers `.github/workflows/release.yml` (DMG build + GitHub release). Before tagging: bump `MARKETING_VERSION` in `project.yml` to match, and make sure the tagged commit builds in Release. Use `/release <version>`.
