import CoreGraphics

/// A single recorded keystroke — everything needed to re-translate it into a
/// different keyboard layout.
struct KeyStroke {
    let keyCode: CGKeyCode
    let flags: CGEventFlags
    /// Input source the key is interpreted in. Mutable so a conversion can
    /// re-tag the strokes to the target layout, making a repeat hotkey undo it.
    var inputSourceID: String
}

/// Ring buffer of recent keystrokes. Lives in memory only and is never
/// persisted or transmitted — deliberately not a keylogger.
final class KeyBuffer {
    private(set) var strokes: [KeyStroke] = []
    private let capacity = 100

    /// Keycodes that end a word but remain in the buffer (space, tab).
    private static let separators: Set<CGKeyCode> = [49, 48]

    var isEmpty: Bool { strokes.isEmpty }

    func append(_ stroke: KeyStroke) {
        strokes.append(stroke)
        if strokes.count > capacity {
            strokes.removeFirst(strokes.count - capacity)
        }
    }

    /// Backspace: the last typed character is gone from the screen too.
    func removeLast() {
        _ = strokes.popLast()
    }

    func reset() {
        strokes.removeAll()
    }

    /// Tail of the buffer covering the last word plus separators typed after
    /// it, so replacing the tail preserves a trailing space.
    func lastWord() -> [KeyStroke] {
        guard let range = lastWordRange() else { return [] }
        return Array(strokes[range])
    }

    /// Re-tags the last word's strokes to a new layout after conversion, so a
    /// repeat hotkey converts them back.
    func retagLastWord(to inputSourceID: String) {
        guard let range = lastWordRange() else { return }
        for i in range { strokes[i].inputSourceID = inputSourceID }
    }

    /// Everything typed since the last reset (phrase conversion).
    func all() -> [KeyStroke] {
        strokes
    }

    private func lastWordRange() -> Range<Int>? {
        guard let lastChar = strokes.lastIndex(where: { !Self.separators.contains($0.keyCode) }) else {
            return nil
        }
        let start = strokes[..<lastChar]
            .lastIndex(where: { Self.separators.contains($0.keyCode) })
            .map { $0 + 1 } ?? 0
        return start ..< strokes.count
    }
}
