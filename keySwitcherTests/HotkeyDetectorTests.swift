import XCTest
@testable import keySwitcher

final class HotkeyDetectorTests: XCTestCase {
    private func keyEvent(keyCode: CGKeyCode, flags: CGEventFlags) -> CGEvent {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)!
        event.flags = flags
        return event
    }

    private func flagsEvent(_ flags: CGEventFlags) -> CGEvent {
        // Any event works; the detector only reads .flags for flagsChanged.
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
        event.flags = flags
        return event
    }

    func testComboFiresOnMatchAndIsSwallowed() {
        let detector = HotkeyDetector()
        detector.hotkey = .optionShiftS
        var fired = 0
        detector.onTrigger = { fired += 1 }

        let swallowed = detector.handleKeyDown(keyEvent(keyCode: 1, flags: [.maskShift, .maskAlternate]))

        XCTAssertTrue(swallowed)
        XCTAssertEqual(fired, 1)
    }

    func testComboIgnoresWrongKey() {
        let detector = HotkeyDetector()
        detector.hotkey = .optionShiftS
        var fired = 0
        detector.onTrigger = { fired += 1 }

        let swallowed = detector.handleKeyDown(keyEvent(keyCode: 2, flags: [.maskShift, .maskAlternate]))

        XCTAssertFalse(swallowed)
        XCTAssertEqual(fired, 0)
    }

    func testComboIgnoresMissingModifier() {
        let detector = HotkeyDetector()
        detector.hotkey = .optionShiftS
        var fired = 0
        detector.onTrigger = { fired += 1 }

        // Shift only, Option missing.
        let swallowed = detector.handleKeyDown(keyEvent(keyCode: 1, flags: [.maskShift]))

        XCTAssertFalse(swallowed)
        XCTAssertEqual(fired, 0)
    }

    func testDoubleShiftFiresWithinWindow() {
        let detector = HotkeyDetector()
        detector.hotkey = .doubleShift
        var clock: TimeInterval = 0
        detector.now = { clock }
        var fired = 0
        detector.onTrigger = { fired += 1 }

        // First tap: press then release.
        detector.handleFlagsChanged(flagsEvent(.maskShift))
        detector.handleFlagsChanged(flagsEvent([]))
        // Second tap 100 ms later.
        clock = 0.1
        detector.handleFlagsChanged(flagsEvent(.maskShift))

        XCTAssertEqual(fired, 1)
    }

    func testDoubleShiftIgnoredOutsideWindow() {
        let detector = HotkeyDetector()
        detector.hotkey = .doubleShift
        var clock: TimeInterval = 0
        detector.now = { clock }
        var fired = 0
        detector.onTrigger = { fired += 1 }

        detector.handleFlagsChanged(flagsEvent(.maskShift))
        detector.handleFlagsChanged(flagsEvent([]))
        clock = 1.0 // too slow
        detector.handleFlagsChanged(flagsEvent(.maskShift))

        XCTAssertEqual(fired, 0)
    }

    func testKeyPressBreaksDoubleTapSequence() {
        let detector = HotkeyDetector()
        detector.hotkey = .doubleShift
        var clock: TimeInterval = 0
        detector.now = { clock }
        var fired = 0
        detector.onTrigger = { fired += 1 }

        detector.handleFlagsChanged(flagsEvent(.maskShift))
        detector.handleFlagsChanged(flagsEvent([]))
        _ = detector.handleKeyDown(keyEvent(keyCode: 0, flags: [])) // typed a letter
        clock = 0.1
        detector.handleFlagsChanged(flagsEvent(.maskShift))

        XCTAssertEqual(fired, 0)
    }
}
