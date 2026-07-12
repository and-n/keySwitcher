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
drag the app to Applications. Releases are signed with a Developer ID and
notarized by Apple, so they launch without any Gatekeeper workaround.

On first launch, grant the Accessibility permission (see below).

### Homebrew (tap)

A cask template is in [`Casks/keyswitcher.rb`](Casks/keyswitcher.rb) for
publishing via a personal tap.

## Permissions

On first launch macOS asks for the **Accessibility** permission
(System Settings → Privacy & Security → Accessibility). It is required to read
keystrokes and replace text; the app polls until it is granted and then starts
automatically. The menu bar icon is dimmed until then.

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

With a `Developer ID Application` identity, set `DEVELOPER_ID` and
`NOTARY_PROFILE` to also sign, notarize and staple the app and DMG.

> Ad-hoc debug builds change signature on each rebuild, so macOS may drop the
> Accessibility grant — re-enable keySwitcher in the list if the icon stays
> dimmed. Notarized releases keep a stable signature and avoid this.

## Roadmap

Automatic dictionary-based layout switching (no hotkey) and per-app exclusions
are planned; see [`PLAN.md`](PLAN.md).

## License

MIT — see [`LICENSE`](LICENSE).
