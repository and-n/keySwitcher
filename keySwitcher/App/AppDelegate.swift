import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private let permissions = PermissionsService()
    private var core: SwitcherCore?
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let statusBar = StatusBarController()
        statusBarController = statusBar

        if permissions.isTrusted {
            startCore()
        } else {
            statusBar.setActive(false)
            permissions.promptSystemDialog()
            showOnboarding()
            permissions.waitForTrust { [weak self] in
                self?.closeOnboarding()
                self?.startCore()
            }
        }
    }

    private func startCore() {
        if core == nil { core = SwitcherCore() }
        let running = core?.start() ?? false
        statusBarController?.setActive(running)
    }

    // MARK: - Accessibility onboarding

    private func showOnboarding() {
        let view = OnboardingView(openSettings: { [permissions] in
            permissions.openAccessibilitySettings()
        })
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "keySwitcher"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        onboardingWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func closeOnboarding() {
        onboardingWindow?.close()
        onboardingWindow = nil
    }
}
