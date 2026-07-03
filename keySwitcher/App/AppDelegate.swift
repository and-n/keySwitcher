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
        let core = self.core ?? SwitcherCore()
        self.core = core

        let running = core.start()
        statusBarController?.setActive(running)

        statusBarController?.onConvert = { [weak core] in
            core?.performConvertMenuAction()
        }
        statusBarController?.onConvertSelection = { [weak core] in
            core?.performConvertSelectionMenuAction()
        }
        statusBarController?.onTogglePause = { [weak core, weak statusBarController] in
            core?.togglePause()
            statusBarController?.setPaused(core?.isPaused ?? false)
        }
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
