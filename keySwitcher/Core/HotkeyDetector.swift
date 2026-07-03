import CoreGraphics
import QuartzCore

/// Recognises the configured hotkey from the raw key/modifier stream.
final class HotkeyDetector {
    var hotkey: Hotkey = .optionShiftS
    var onTrigger: (() -> Void)?

    /// Max gap between the two taps of a double-tap hotkey.
    var doubleTapWindow: TimeInterval = 0.3
    /// Injectable clock so double-tap timing is testable.
    var now: () -> TimeInterval = { CACurrentMediaTime() }

    /// Sentinel meaning "no first tap is pending" — far enough in the past
    /// that no real timestamp falls within the double-tap window of it.
    private static let noPendingTap = -Double.greatestFiniteMagnitude

    private var lastFlags: CGEventFlags = []
    private var lastTapTime: TimeInterval = HotkeyDetector.noPendingTap

    /// Feeds a keyDown to the detector. Returns true when the event is the
    /// hotkey and must be swallowed (so the chord's letter is not typed).
    func handleKeyDown(_ event: CGEvent) -> Bool {
        // Any real key press breaks a pending double-tap sequence.
        lastTapTime = Self.noPendingTap

        guard case let .combo(keyCode, modifiers) = hotkey else { return false }
        let pressed = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        guard pressed == keyCode else { return false }
        guard event.flags.significantModifiersOnly == modifiers.significantModifiersOnly else { return false }

        onTrigger?()
        return true
    }

    func handleFlagsChanged(_ event: CGEvent) {
        let flags = event.flags.significantModifiersOnly
        defer { lastFlags = flags }

        guard case let .doubleTap(modifier) = hotkey else { return }
        let target = modifier.significantModifiersOnly

        // Rising edge: the target modifier just went down and is the only
        // modifier held (so Shift+Cmd taps don't count).
        let isRisingEdge = !lastFlags.contains(target) && flags.contains(target) && flags == target
        guard isRisingEdge else { return }

        let t = now()
        if t - lastTapTime <= doubleTapWindow {
            lastTapTime = Self.noPendingTap
            onTrigger?()
        } else {
            lastTapTime = t
        }
    }
}
