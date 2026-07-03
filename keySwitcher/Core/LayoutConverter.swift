import Carbon.HIToolbox
import CoreGraphics
import os

/// Translates keystrokes into characters for a given keyboard layout via
/// UCKeyTranslate. Works for any layout pair — no hardcoded tables.
final class LayoutConverter {
    private var layoutDataCache: [String: Data] = [:]
    private let log = Logger(subsystem: "com.tonevitskiy.keySwitcher", category: "converter")

    /// Character(s) produced by a keystroke in the given layout (defaults to
    /// the layout the stroke was typed in). Nil for non-character keys and
    /// for input methods that expose no key layout data.
    func characters(for stroke: KeyStroke, inLayout sourceID: String? = nil) -> String? {
        guard let data = layoutData(for: sourceID ?? stroke.inputSourceID) else { return nil }

        // UCKeyTranslate takes EventRecord-style modifiers shifted right by 8.
        var modifiers: UInt32 = 0
        if stroke.flags.contains(.maskShift) { modifiers |= UInt32(shiftKey >> 8) }
        if stroke.flags.contains(.maskAlphaShift) { modifiers |= UInt32(alphaLock >> 8) }

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0

        let status = data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> OSStatus in
            guard let layout = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
                return OSStatus(-1)
            }
            return UCKeyTranslate(
                layout,
                UInt16(stroke.keyCode),
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

    /// Readable form of a stroke sequence (debug logging, conversion).
    func text(for strokes: [KeyStroke], inLayout sourceID: String? = nil) -> String {
        strokes.compactMap { characters(for: $0, inLayout: sourceID) }.joined()
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
