# keySwitcher

A native, open-source macOS menu bar utility that fixes text typed in the
wrong keyboard layout — the classic `ghbdtn` → `привет` problem. An open
alternative to Punto Switcher and similar tools.

Press a hotkey (default **⌥⇧S**) and keySwitcher re-types your last word or
phrase in the other layout and switches the system input source to match.

## Status

Early development. See [`PLAN.md`](PLAN.md) for the roadmap.

- [x] Stage 0 — menu bar app skeleton, Accessibility onboarding
- [x] Stage 1 — global keystroke interception and in-memory buffer
- [x] Stage 2 — layout conversion engine (`UCKeyTranslate`) + text replacement *(engine done & tested; hotkey wiring next)*
- [ ] Stage 3 — hotkeys and live layout indicator
- [ ] Stage 4 — selection conversion
- [ ] Stage 5 — settings window
- [ ] Stage 6 — signed & notarized release

## Privacy

keySwitcher is **not** a keylogger. Keystrokes are kept only in memory (the
last ~100), are never written to disk and never leave your Mac. In secure
input fields (password fields) nothing is recorded at all. The source is open
so you can verify this.

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

## Permissions

On first launch macOS will ask for the **Accessibility** permission
(System Settings → Privacy & Security → Accessibility). It is required to read
keystrokes and replace text; the app polls until it is granted and then starts
automatically.

> Note: while developing, rebuilding can change the app's code signature and
> macOS may drop the Accessibility grant. Re-enable keySwitcher in the list if
> the menu bar icon appears dimmed. A stable Developer ID signature avoids this.

## License

MIT — see [`LICENSE`](LICENSE).
