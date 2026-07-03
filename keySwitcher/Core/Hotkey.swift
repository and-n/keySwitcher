import CoreGraphics

/// A trigger the user can bind to conversion.
enum Hotkey: Equatable {
    /// A regular chord, e.g. ⌥⇧S = `.combo(keyCode: 1, modifiers: [.maskShift, .maskAlternate])`.
    case combo(keyCode: CGKeyCode, modifiers: CGEventFlags)
    /// A single modifier tapped twice in quick succession, e.g. double-Shift.
    case doubleTap(modifier: CGEventFlags)

    /// Default binding: Option+Shift+S (keycode 1 == ANSI "S").
    static let optionShiftS = Hotkey.combo(keyCode: 1, modifiers: [.maskShift, .maskAlternate])
    static let doubleShift = Hotkey.doubleTap(modifier: .maskShift)
}

extension CGEventFlags {
    /// The device-independent modifier bits we care about, ignoring caps lock,
    /// numeric pad, function and left/right-specific device flags.
    static let significantModifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]

    var significantModifiersOnly: CGEventFlags { intersection(.significantModifiers) }
}
