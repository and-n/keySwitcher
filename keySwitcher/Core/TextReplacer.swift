import CoreGraphics
import Foundation

/// Replaces text at the caret by synthesizing Backspace presses followed by
/// Unicode text events. All events are tagged with the synthetic marker so
/// our own tap passes them through without recording.
final class TextReplacer {
    private let eventSource: CGEventSource

    init?() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return nil }
        source.userData = EventTapManager.syntheticEventMarker
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
