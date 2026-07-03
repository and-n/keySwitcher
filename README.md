# keySwitcher

A native, open-source macOS menu bar utility that fixes text typed in the
wrong keyboard layout — the classic `ghbdtn` → `привет` problem. An open
alternative to Punto Switcher and similar tools.

Press a hotkey and keySwitcher re-types your last word in the other layout and
switches the system input source to match. It works with any pair of keyboard
layouts (not just RU/EN) because conversion goes through the system's own key
layout data.

## Features

- **Convert the last typed word** — default **⌥⇧S**. Press again to convert back.
- **Convert the selected text** — default **⌥⇧D**. Uses the Accessibility API,
  falling back to a copy/paste dance in apps that don't expose the selection.
- **Any layout pair** — taken from your system. With exactly two layouts it is
  automatic; with more, pick the pair in Settings.
- **Menu bar indicator** of the current layout (EN/RU/…), with Pause.
- **Configurable hotkeys** — presets (incl. double-Shift) or record your own.
- **Launch at login**.
- Lives in the menu bar only (no Dock icon).

## Install

### From a release

Download `keySwitcher.dmg` from the [Releases](../../releases) page, open it and
drag the app to Applications.

Because the app is not yet notarized (no Apple Developer ID — see Status),
Gatekeeper will block it on first launch. Remove the quarantine flag once:

```sh
xattr -dr com.apple.quarantine /Applications/keySwitcher.app
```

Then launch it and grant the Accessibility permission (see below).

### Homebrew (tap)

A cask template is in [`Casks/keyswitcher.rb`](Casks/keyswitcher.rb) for
publishing via a personal tap.

## Permissions

On first launch macOS asks for the **Accessibility** permission
(System Settings → Privacy & Security → Accessibility). It is required to read
keystrokes and replace text; the app polls until it is granted and then starts
automatically. The menu bar icon is dimmed until then.

> While developing, rebuilding can change the app's code signature and macOS may
> drop the Accessibility grant — re-enable keySwitcher in the list if the icon
> stays dimmed. A stable Developer ID signature avoids this.

## Privacy

keySwitcher is **not** a keylogger. Keystrokes are kept only in memory (the
last ~100) to know what the last word was, are never written to disk and never
leave your Mac. In secure input fields (password fields) nothing is recorded at
all. The source is open so you can verify this.

## Building from source

Requires Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`). The Xcode project is generated from `project.yml`
and is not checked in.

```sh
xcodegen generate
xcodebuild -scheme keySwitcher -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/keySwitcher.app
```

Run the tests:

```sh
xcodebuild -scheme keySwitcher -derivedDataPath build test
```

The conversion tests expect the **ABC** and **Russian** keyboard layouts to be
installed; they skip themselves otherwise.

Build a distributable `.dmg` (universal, ad-hoc signed):

```sh
./scripts/build-release.sh
```

Set `DEVELOPER_ID` (and `NOTARY_PROFILE`) to sign and notarize once a
certificate is available.

## Status

MVP feature-complete; packaging in progress. See [`PLAN.md`](PLAN.md).

- [x] Stage 0 — menu bar app skeleton, Accessibility onboarding
- [x] Stage 1 — global keystroke interception and in-memory buffer
- [x] Stage 2 — layout conversion engine (`UCKeyTranslate`) + text replacement
- [x] Stage 3 — hotkeys (⌥⇧S / double-Shift), conversion trigger, live layout indicator
- [x] Stage 4 — selection conversion (⌥⇧D) via Accessibility, clipboard fallback
- [x] Stage 5 — settings window (hotkeys, layout pair, launch at login)
- [x] Stage 6 — release packaging (`.dmg`, CI); **notarization pending a Developer ID**

## License

MIT — see [`LICENSE`](LICENSE).
