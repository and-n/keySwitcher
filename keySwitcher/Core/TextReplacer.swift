import CoreGraphics
import Foundation

/// Replaces text at the caret by synthesizing Backspace presses followed by
/// Unicode text events. All events are tagged with the synthetic marker so
/// our own tap passes them through without recording.
final class TextReplacer {
    private let eventSource: CGEventSource?

    init() {
        // Private state, not combinedSessionState: the hotkey's modifiers
        // (e.g. ⌥⇧) are often still physically held when a replacement runs.
        // A combined-state source merges those held modifiers into our events
        // despite `flags = []`, turning Backspace into ⌥⌫ (delete word) and
        // corrupting the Unicode insert — the word vanishes on the first press.
        let source = CGEventSource(stateID: .privateState)
        source?.userData = EventTapManager.syntheticEventMarker
        eventSource = source
    }

    func replace(charactersToErase count: Int, with text: String) {
        for _ in 0..<count {
            postKeyPress(keyCode: 51) // backspace
        }
        // A single event carries at most 20 UTF-16 units.
        let units = Array(text.utf16)
        var index = 0
        while index < units.count {
            let chunk = Array(units[index ..< min(index + 20, units.count)])
            postUnicode(chunk)
            index += chunk.count
        }
    }

    /// Posts a modifier chord (e.g. Cmd+C) as a marked synthetic event.
    func postKeyChord(keyCode: CGKeyCode, flags: CGEventFlags) {
        guard let down = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false) else { return }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        usleep(5_000)
    }

    private func postKeyPress(keyCode: CGKeyCode) {
        guard let down = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false) else { return }
        // Clear flags: the user may still be holding the hotkey modifiers,
        // and Option+Backspace would delete a whole word.
        down.flags = []
        up.flags = []
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        usleep(1_000)
    }

    private func postUnicode(_ units: [UniChar]) {
        guard let down = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: false) else { return }
        var units = units
        down.flags = []
        up.flags = []
        down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
        up.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        usleep(1_000)
    }
}
