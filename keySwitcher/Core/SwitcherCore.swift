import AppKit
import Carbon.HIToolbox
import os

/// Wires the event tap, keystroke buffer and converter together.
/// Everything runs on the main thread.
final class SwitcherCore {
    private let eventTap = EventTapManager()
    private let keyBuffer = KeyBuffer()
    private let converter = LayoutConverter()
    private let log = Logger(subsystem: "com.tonevitskiy.keySwitcher", category: "core")

    private var workspaceObserver: NSObjectProtocol?

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
        eventTap.keyDownHandler = { [weak self] event in
            self?.handleKeyDown(event) ?? false
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

    /// Returns true when the event must be swallowed (hotkeys — stage 3).
    private func handleKeyDown(_ event: CGEvent) -> Bool {
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

        #if DEBUG
        let word = converter.text(for: keyBuffer.lastWord())
        log.debug("last word: \(word, privacy: .public)")
        #endif

        return false
    }
}
