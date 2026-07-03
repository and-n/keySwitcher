import AppKit
import ApplicationServices

/// Checks and requests the Accessibility permission required for CGEventTap.
final class PermissionsService {
    private var pollTimer: Timer?

    var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system "keySwitcher would like to control this computer" dialog
    /// and adds the app to the Accessibility list (unchecked).
    func promptSystemDialog() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    /// Polls once per second until the permission is granted. macOS posts no
    /// notification when the user flips the toggle in System Settings.
    func waitForTrust(onGranted: @escaping () -> Void) {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard AXIsProcessTrusted() else { return }
            timer.invalidate()
            self?.pollTimer = nil
            onGranted()
        }
    }
}
