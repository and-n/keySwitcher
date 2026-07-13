import AppKit
import ApplicationServices
import os

/// Converts the current selection between layouts. Tries the Accessibility API
/// first (clean, no clipboard side effects); falls back to a copy/paste dance
/// for apps that don't expose selected text over AX (Chrome, many Electron).
final class SelectionConverter {
    private let converter: LayoutConverter
    private let replacer: TextReplacer
    private let log = Logger(subsystem: "com.tonevitskiy.keySwitcher", category: "selection")

    private let cKeyCode: CGKeyCode = 8
    private let vKeyCode: CGKeyCode = 9

    init(converter: LayoutConverter, replacer: TextReplacer) {
        self.converter = converter
        self.replacer = replacer
    }

    func convert(pair: LayoutPair) {
        if convertViaAccessibility(pair: pair) { return }
        convertViaPasteboard(pair: pair)
    }

    // MARK: - Accessibility path

    private func convertViaAccessibility(pair: LayoutPair) -> Bool {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focusedElement = focused,
              CFGetTypeID(focusedElement) == AXUIElementGetTypeID() else {
            return false
        }
        // CFTypeRef has no conditional cast; type-checked above.
        // swiftlint:disable:next force_cast
        let element = focusedElement as! AXUIElement

        var selected: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selected) == .success,
              let text = selected as? String, !text.isEmpty else {
            return false
        }

        let converted = converter.convertSelection(text, pair: pair)
        guard converted != text else { return true } // handled: nothing to change

        let result = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, converted as CFString)
        if result != .success {
            log.debug("AX set selected text failed (\(result.rawValue)), falling back to clipboard")
            return false
        }
        InputSourceManager.select(id: converter.targetLayout(for: text, pair: pair))
        return true
    }

    // MARK: - Clipboard fallback

    private func convertViaPasteboard(pair: LayoutPair) {
        let pasteboard = NSPasteboard.general
        let savedString = pasteboard.string(forType: .string)
        let changeCountBeforeCopy = pasteboard.changeCount

        replacer.postKeyChord(keyCode: cKeyCode, flags: .maskCommand)

        waitForPasteboard(pasteboard, changedFrom: changeCountBeforeCopy) { [weak self] copied in
            guard let self else { return }
            defer { self.restore(savedString, to: pasteboard) }

            guard let text = copied, !text.isEmpty else { return }
            let converted = self.converter.convertSelection(text, pair: pair)
            guard converted != text else { return }

            pasteboard.clearContents()
            pasteboard.setString(converted, forType: .string)
            self.replacer.postKeyChord(keyCode: self.vKeyCode, flags: .maskCommand)
            InputSourceManager.select(id: self.converter.targetLayout(for: text, pair: pair))
        }
    }

    /// Polls the pasteboard (copy is asynchronous) up to ~0.3 s.
    private func waitForPasteboard(
        _ pasteboard: NSPasteboard,
        changedFrom oldCount: Int,
        attempt: Int = 0,
        completion: @escaping (String?) -> Void
    ) {
        if pasteboard.changeCount != oldCount {
            completion(pasteboard.string(forType: .string))
            return
        }
        guard attempt < 15 else {
            completion(nil)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
            self?.waitForPasteboard(pasteboard, changedFrom: oldCount, attempt: attempt + 1, completion: completion)
        }
    }

    /// Restores the user's clipboard after the paste has been consumed.
    private func restore(_ savedString: String?, to pasteboard: NSPasteboard) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            pasteboard.clearContents()
            if let savedString {
                pasteboard.setString(savedString, forType: .string)
            }
        }
    }
}
