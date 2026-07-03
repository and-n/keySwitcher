import ServiceManagement
import os

/// Thin wrapper over SMAppService for the "start at login" toggle (macOS 13+).
enum LaunchAtLogin {
    private static let log = Logger(subsystem: "com.tonevitskiy.keySwitcher", category: "login-item")

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            log.error("Failed to \(enabled ? "register" : "unregister", privacy: .public) login item: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
