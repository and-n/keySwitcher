import AppKit
import os

/// Owns the global CGEventTap. The tap is attached to the main run loop
/// (common modes): the app does no heavy work on the main thread, and keeping
/// the callback there makes TIS/AppKit calls in the handlers safe.
final class EventTapManager {
    /// Called on every hardware keyDown. Return true to swallow the event
    /// (used for hotkeys so the `s` of Option+Shift+S never reaches the app).
    var keyDownHandler: ((CGEvent) -> Bool)?
    /// Called on modifier changes (double-Shift hotkey detection).
    var flagsChangedHandler: ((CGEvent) -> Void)?
    /// Called on any mouse button press (the caret likely moved).
    var mouseDownHandler: (() -> Void)?

    /// Marker set on synthetic events posted by TextReplacer so the tap can
    /// tell its own output from real typing and pass it through untouched.
    static let syntheticEventMarker: Int64 = 0x6B65_5357 // "keSW"

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let log = Logger(subsystem: "com.tonevitskiy.keySwitcher", category: "event-tap")

    func start() -> Bool {
        guard tap == nil else { return true }

        let mask: CGEventMask =
            1 << CGEventType.keyDown.rawValue
            | 1 << CGEventType.flagsChanged.rawValue
            | 1 << CGEventType.leftMouseDown.rawValue
            | 1 << CGEventType.rightMouseDown.rawValue
            | 1 << CGEventType.otherMouseDown.rawValue

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
            return manager.handle(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            log.error("Failed to create event tap — Accessibility permission missing or revoked")
            return false
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        log.info("Event tap started")
        return true
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        runLoopSource = nil
        tap = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // macOS disables taps whose callback responds too slowly; re-enable.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            log.warning("Event tap was disabled by the system (\(type.rawValue)), re-enabled")
            return Unmanaged.passUnretained(event)
        }

        // Our own synthetic events (text replacement) pass through untouched.
        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticEventMarker {
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .keyDown:
            if keyDownHandler?(event) == true { return nil }
        case .flagsChanged:
            flagsChangedHandler?(event)
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            mouseDownHandler?()
        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }
}
