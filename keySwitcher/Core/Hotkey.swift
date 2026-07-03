import CoreGraphics

/// A trigger the user can bind to conversion.
enum Hotkey: Equatable {
    /// A regular chord, e.g. ⌥⇧S = `.combo(keyCode: 1, modifiers: [.maskShift, .maskAlternate])`.
    case combo(keyCode: CGKeyCode, modifiers: CGEventFlags)
    /// A single modifier tapped twice in quick succession, e.g. double-Shift.
    case doubleTap(modifier: CGEventFlags)

    /// Default binding: Option+Shift+S (keycode 1 == ANSI "S").
    static let optionShiftS = Hotkey.combo(keyCode: 1, modifiers: [.maskShift, .maskAlternate])
    /// Default selection binding: Option+Shift+D (keycode 2 == ANSI "D").
    static let optionShiftD = Hotkey.combo(keyCode: 2, modifiers: [.maskShift, .maskAlternate])
    static let doubleShift = Hotkey.doubleTap(modifier: .maskShift)

    /// Human-readable form for the UI, e.g. "⌥⇧S" or "Double ⇧".
    var displayString: String {
        switch self {
        case let .combo(keyCode, modifiers):
            return modifiers.glyphs + KeyCodeNames.label(for: keyCode)
        case let .doubleTap(modifier):
            return "Double " + modifier.glyphs
        }
    }
}

extension Hotkey: Codable {
    private enum CodingKeys: String, CodingKey { case kind, keyCode, modifiers }
    private enum Kind: String, Codable { case combo, doubleTap }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let modifiers = CGEventFlags(rawValue: try container.decode(UInt64.self, forKey: .modifiers))
        switch try container.decode(Kind.self, forKey: .kind) {
        case .combo:
            let keyCode = try container.decode(UInt16.self, forKey: .keyCode)
            self = .combo(keyCode: keyCode, modifiers: modifiers)
        case .doubleTap:
            self = .doubleTap(modifier: modifiers)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .combo(keyCode, modifiers):
            try container.encode(Kind.combo, forKey: .kind)
            try container.encode(UInt16(keyCode), forKey: .keyCode)
            try container.encode(modifiers.rawValue, forKey: .modifiers)
        case let .doubleTap(modifier):
            try container.encode(Kind.doubleTap, forKey: .kind)
            try container.encode(modifier.rawValue, forKey: .modifiers)
        }
    }
}

extension CGEventFlags {
    /// Modifier glyphs in the conventional macOS order: ⌃⌥⇧⌘.
    var glyphs: String {
        var result = ""
        if contains(.maskControl) { result += "⌃" }
        if contains(.maskAlternate) { result += "⌥" }
        if contains(.maskShift) { result += "⇧" }
        if contains(.maskCommand) { result += "⌘" }
        return result
    }
}

extension CGEventFlags {
    /// The device-independent modifier bits we care about, ignoring caps lock,
    /// numeric pad, function and left/right-specific device flags.
    static let significantModifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]

    var significantModifiersOnly: CGEventFlags { intersection(.significantModifiers) }
}
