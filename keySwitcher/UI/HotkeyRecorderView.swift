import AppKit
import SwiftUI

/// A field that records a key chord (a key plus at least one modifier) and
/// reports it as a `.combo` hotkey. Modifier-only hotkeys like double-Shift are
/// offered as presets, not recorded here.
struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var hotkey: Hotkey

    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton()
        button.onRecord = { hotkey = $0 }
        return button
    }

    func updateNSView(_ nsView: RecorderButton, context: Context) {
        nsView.hotkey = hotkey
    }

    final class RecorderButton: NSButton {
        var hotkey: Hotkey = .optionShiftS { didSet { refreshTitle() } }
        var onRecord: ((Hotkey) -> Void)?
        private var isRecording = false {
            didSet { refreshTitle() }
        }

        override init(frame: NSRect) {
            super.init(frame: frame)
            bezelStyle = .rounded
            setButtonType(.momentaryPushIn)
            target = self
            action = #selector(startRecording)
            refreshTitle()
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override var acceptsFirstResponder: Bool { true }

        @objc private func startRecording() {
            isRecording = true
            window?.makeFirstResponder(self)
        }

        override func resignFirstResponder() -> Bool {
            isRecording = false
            return super.resignFirstResponder()
        }

        override func keyDown(with event: NSEvent) {
            guard isRecording else { super.keyDown(with: event); return }

            if event.keyCode == 53 { // Escape cancels
                stopRecording()
                return
            }

            let modifiers = Self.cgFlags(from: event.modifierFlags)
            guard !modifiers.isEmpty else {
                NSSound.beep() // a bare key would collide with normal typing
                return
            }

            let recorded = Hotkey.combo(keyCode: event.keyCode, modifiers: modifiers)
            hotkey = recorded
            onRecord?(recorded)
            stopRecording()
        }

        private func stopRecording() {
            isRecording = false
            window?.makeFirstResponder(nil)
        }

        private func refreshTitle() {
            title = isRecording ? "Press keys…" : hotkey.displayString
        }

        private static func cgFlags(from flags: NSEvent.ModifierFlags) -> CGEventFlags {
            var result: CGEventFlags = []
            if flags.contains(.shift) { result.insert(.maskShift) }
            if flags.contains(.control) { result.insert(.maskControl) }
            if flags.contains(.option) { result.insert(.maskAlternate) }
            if flags.contains(.command) { result.insert(.maskCommand) }
            return result
        }
    }
}
