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
    private let selectionHotkeys = HotkeyDetector()
    private let replacer = TextReplacer()
    private lazy var selectionConverter = SelectionConverter(converter: converter, replacer: replacer)
    private let store = SettingsStore.shared
    private let log = Logger(subsystem: "com.tonevitskiy.keySwitcher", category: "core")

    private var workspaceObserver: NSObjectProtocol?
    private var settingsObserver: NSObjectProtocol?
    private var recordingObserver: NSObjectProtocol?

    private(set) var isPaused = false
    /// True while the settings recorder is capturing a chord; hotkey matching
    /// is suspended so the chord reaches the recorder instead of firing here.
    private var isRecordingHotkey = false

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
        applySettings()

        hotkeys.onTrigger = { [weak self] in self?.convertLastWord() }
        selectionHotkeys.onTrigger = { [weak self] in self?.convertSelection() }

        eventTap.keyDownHandler = { [weak self] event in
            self?.handleKeyDown(event) ?? false
        }
        eventTap.flagsChangedHandler = { [weak self] event in
            guard let self, !self.isRecordingHotkey else { return }
            self.hotkeys.handleFlagsChanged(event)
            self.selectionHotkeys.handleFlagsChanged(event)
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
        settingsObserver = NotificationCenter.default.addObserver(
            forName: SettingsStore.didChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applySettings()
        }
        recordingObserver = NotificationCenter.default.addObserver(
            forName: .hotkeyRecording,
            object: nil,
            queue: .main
        ) { [weak self] note in
            self?.isRecordingHotkey = note.userInfo?["isRecording"] as? Bool ?? false
        }
        return eventTap.start()
    }

    func stop() {
        eventTap.stop()
        keyBuffer.reset()
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
        if let recordingObserver {
            NotificationCenter.default.removeObserver(recordingObserver)
        }
        workspaceObserver = nil
        settingsObserver = nil
        recordingObserver = nil
    }

    private func applySettings() {
        hotkeys.hotkey = store.wordHotkey
        selectionHotkeys.hotkey = store.selectionHotkey
    }

    private func resolvedPair() -> LayoutPair? {
        InputSourceManager.currentPair(override: store.layoutPairOverride)
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

    func performConvertSelectionMenuAction() {
        convertSelection()
    }

    /// Returns true when the event must be swallowed.
    private func handleKeyDown(_ event: CGEvent) -> Bool {
        // While the settings recorder is capturing, pass everything through
        // untouched so the chord lands in the recorder field.
        guard !isRecordingHotkey else { return false }

        // Hotkeys first, so their chord letters are never typed or recorded.
        if hotkeys.handleKeyDown(event) { return true }
        if selectionHotkeys.handleKeyDown(event) { return true }

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

        guard let pair = resolvedPair(),
              let targetID = pair.other(than: lastStroke.inputSourceID) else {
            log.info("No unambiguous layout pair — conversion skipped")
            return
        }

        let converted = converter.text(for: strokes, inLayout: targetID)
        guard !converted.isEmpty, converted != currentText else { return }

        // Defer the actual typing off the tap callback to avoid re-entrancy.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Switch the layout *before* typing: doing it afterwards lets the
            // input-source change race the still-in-flight synthetic text.
            InputSourceManager.select(id: targetID)
            self.replacer.replace(charactersToErase: currentText.count, with: converted)
            self.keyBuffer.retagLastWord(to: targetID)
        }
    }

    private func convertSelection() {
        guard !isPaused else { return }
        guard let pair = resolvedPair() else {
            log.info("No unambiguous layout pair — selection conversion skipped")
            return
        }
        // Defer off the tap callback; the converter posts its own events.
        DispatchQueue.main.async { [weak self] in
            self?.selectionConverter.convert(pair: pair)
        }
    }
}
