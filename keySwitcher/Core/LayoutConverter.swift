import Carbon.HIToolbox
import CoreGraphics
import os

/// Translates between keyboard layouts via UCKeyTranslate. Works for any
/// layout pair — no hardcoded tables.
///
/// Two modes:
/// - keycode-based (`characters(for:)`) for freshly typed text, where the
///   physical keys are known;
/// - character-based (`convertSelection(_:pair:)`) for already-displayed text,
///   where only the characters are known and the keys must be inferred.
final class LayoutConverter {
    private struct KeyMapping {
        let keyCode: CGKeyCode
        let shift: Bool
    }

    private var layoutDataCache: [String: Data] = [:]
    private var reverseMapCache: [String: [Character: KeyMapping]] = [:]
    private let log = Logger(subsystem: "com.tonevitskiy.keySwitcher", category: "converter")

    // MARK: - Keycode-based (typed text)

    /// Character(s) produced by a keystroke in the given layout (defaults to
    /// the layout the stroke was typed in).
    func characters(for stroke: KeyStroke, inLayout sourceID: String? = nil) -> String? {
        guard let data = layoutData(for: sourceID ?? stroke.inputSourceID) else { return nil }
        return translate(
            keyCode: stroke.keyCode,
            shift: stroke.flags.contains(.maskShift),
            capsLock: stroke.flags.contains(.maskAlphaShift),
            data: data
        )
    }

    /// Readable form of a stroke sequence.
    func text(for strokes: [KeyStroke], inLayout sourceID: String? = nil) -> String {
        strokes.compactMap { characters(for: $0, inLayout: sourceID) }.joined()
    }

    // MARK: - Character-based (selected text)

    /// Re-interprets already-typed text in the other layout of the pair.
    /// The whole selection's dominant script decides the direction, so mixed
    /// punctuation doesn't flip conversion mid-string.
    func convertSelection(_ text: String, pair: LayoutPair) -> String {
        guard !text.isEmpty,
              let dataA = layoutData(for: pair.a),
              let dataB = layoutData(for: pair.b) else {
            return text
        }
        let mapA = reverseMap(for: pair.a)
        let mapB = reverseMap(for: pair.b)

        // Pick the source layout as the one that can type more of the letters.
        let scoreA = text.reduce(0) { $0 + ($1.isLetter && mapA[$1] != nil ? 1 : 0) }
        let scoreB = text.reduce(0) { $0 + ($1.isLetter && mapB[$1] != nil ? 1 : 0) }
        let (sourceMap, targetData) = scoreA >= scoreB ? (mapA, dataB) : (mapB, dataA)

        var result = ""
        result.reserveCapacity(text.count)
        for ch in text {
            if let mapping = sourceMap[ch],
               let translated = translate(keyCode: mapping.keyCode, shift: mapping.shift, capsLock: false, data: targetData) {
                result += translated
            } else {
                result.append(ch)
            }
        }
        return result
    }

    // MARK: - Low-level translation

    private func translate(keyCode: CGKeyCode, shift: Bool, capsLock: Bool, data: Data) -> String? {
        // UCKeyTranslate takes EventRecord-style modifiers shifted right by 8.
        var modifiers: UInt32 = 0
        if shift { modifiers |= UInt32(shiftKey >> 8) }
        if capsLock { modifiers |= UInt32(alphaLock >> 8) }

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0

        let status = data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> OSStatus in
            guard let layout = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
                return OSStatus(-1)
            }
            return UCKeyTranslate(
                layout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDown),
                modifiers,
                UInt32(LMGetKbdType()),
                OptionBits(1 << kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars
            )
        }

        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }

    /// character -> (keyCode, shift) for a layout. Built once per layout by
    /// walking every key with and without Shift.
    private func reverseMap(for sourceID: String) -> [Character: KeyMapping] {
        if let cached = reverseMapCache[sourceID] { return cached }
        guard let data = layoutData(for: sourceID) else { return [:] }

        var map: [Character: KeyMapping] = [:]
        for keyCode in CGKeyCode(0)...CGKeyCode(127) {
            for shift in [false, true] {
                guard let produced = translate(keyCode: keyCode, shift: shift, capsLock: false, data: data),
                      produced.count == 1,
                      let ch = produced.first,
                      isPrintable(ch) else {
                    continue
                }
                // Prefer the unshifted binding for a character (checked first).
                if map[ch] == nil {
                    map[ch] = KeyMapping(keyCode: keyCode, shift: shift)
                }
            }
        }
        reverseMapCache[sourceID] = map
        return map
    }

    private func isPrintable(_ ch: Character) -> Bool {
        guard let scalar = ch.unicodeScalars.first, ch.unicodeScalars.count == 1 else { return false }
        return scalar.value >= 0x20 && scalar.value != 0x7F
    }

    private func layoutData(for sourceID: String) -> Data? {
        if let cached = layoutDataCache[sourceID] { return cached }
        guard let source = InputSourceManager.source(withID: sourceID),
              let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            log.warning("No key layout data for input source \(sourceID, privacy: .public)")
            return nil
        }
        let data = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
        layoutDataCache[sourceID] = data
        return data
    }
}
