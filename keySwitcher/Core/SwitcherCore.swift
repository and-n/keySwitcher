import AppKit
import Carbon.HIToolbox
import os

/// Wires the event tap, keystroke buffer, hotkey detector and converter
/// together. Everything runs on the main thread.
final class SwitcherCore {
    private let eventTap = EventTapManager()
    private let keyBuffer = KeyBuffer()
    private let converter = LayoutConverter()
    private let hotkeys = HotkeyDetector()
    private let replacer = TextReplacer()
    private let log = Logger(subsystem: "com.tonevitskiy.keySwitcher", category: "core")

    private var workspaceObserver: NSObjectProtocol?

    private(set) var isPaused = false

    // Keys after which the buffer no longer matches what precedes the caret.
    private static let resetKeyCodes: Set<CGKeyCode> = [
        36, 76,             // return, keypad enter
        53,                 // escape
        123, 124, 125, 126, // arrows
        115, 119, 116, 121, // home, end, page up, page down
        117,                // forward delete
    ]
    private static let backspaceKeyCode: CGKeyCode = 51

    func start() -> Bool {
        hotkeys.onTrigger = { [weak self] in self?.convertLastWord() }
        eventTap.keyDownHandler = { [weak self] event in
            self?.handleKeyDown(event) ?? false
        }
        eventTap.flagsChangedHandler = { [weak self] event in
            self?.hotkeys.handleFlagsChanged(event)
        }
        eventTap.mouseDownHandler = { [weak self] in
            self?.keyBuffer.reset()
        }
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.keyBuffer.reset()
        }
        return eventTap.start()
    }

    func stop() {
        eventTap.stop()
        keyBuffer.reset()
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
        workspaceObserver = nil
    }

    func togglePause() {
        isPaused.toggle()
        if isPaused { keyBuffer.reset() }
    }

    func setHotkey(_ hotkey: Hotkey) {
        hotkeys.hotkey = hotkey
    }

    /// Convert triggered from the menu rather than the hotkey.
    func performConvertMenuAction() {
        convertLastWord()
    }

    /// Returns true when the event must be swallowed.
    private func handleKeyDown(_ event: CGEvent) -> Bool {
        // Hotkey first, so its chord letter is never typed or recorded.
        if hotkeys.handleKeyDown(event) { return true }

        // Password fields and the like: record nothing at all.
        guard !IsSecureEventInputEnabled() else { return false }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        // Command/Control shortcuts produce no text and move focus around.
        if flags.contains(.maskCommand) || flags.contains(.maskControl) {
            keyBuffer.reset()
            return false
        }

        if keyCode == Self.backspaceKeyCode {
            keyBuffer.removeLast()
            return false
        }

        if Self.resetKeyCodes.contains(keyCode) {
            keyBuffer.reset()
            return false
        }

        guard let sourceID = InputSourceManager.currentSourceID() else { return false }
        keyBuffer.append(KeyStroke(keyCode: keyCode, flags: flags, inputSourceID: sourceID))
        return false
    }

    private func convertLastWord() {
        guard !isPaused else { return }
        let strokes = keyBuffer.lastWord()
        guard let lastStroke = strokes.last else { return }

        // What is currently on screen, in the layout(s) it was typed in.
        let currentText = converter.text(for: strokes)
        guard !currentText.isEmpty else { return }

        guard let pair = InputSourceManager.currentPair(),
              let targetID = pair.other(than: lastStroke.inputSourceID) else {
            log.info("No unambiguous layout pair — conversion skipped")
            return
        }

        let converted = converter.text(for: strokes, inLayout: targetID)
        guard !converted.isEmpty, converted != currentText else { return }

        // Defer the actual typing off the tap callback to avoid re-entrancy.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.replacer.replace(charactersToErase: currentText.count, with: converted)
            InputSourceManager.select(id: targetID)
            self.keyBuffer.retagLastWord(to: targetID)
        }
    }
}
