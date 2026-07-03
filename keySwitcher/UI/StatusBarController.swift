import AppKit
import Carbon.HIToolbox

/// Owns the NSStatusItem: shows the current input source as a short code
/// (EN/RU) and hosts the menu.
final class StatusBarController {
    var onConvert: (() -> Void)?
    var onConvertSelection: (() -> Void)?
    var onTogglePause: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    private let statusItem: NSStatusItem
    private var pauseItem: NSMenuItem?
    private var sourceObserver: NSObjectProtocol?
    private var isPaused = false

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = makeMenu()
        refreshIndicator()

        // TIS posts this via the distributed center when the layout changes.
        sourceObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshIndicator()
        }
    }

    deinit {
        if let sourceObserver {
            DistributedNotificationCenter.default().removeObserver(sourceObserver)
        }
    }

    /// Dimmed while the Accessibility permission is missing or when paused.
    func setActive(_ active: Bool) {
        statusItem.button?.appearsDisabled = !active
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        pauseItem?.title = paused ? "Resume" : "Pause"
        statusItem.button?.appearsDisabled = paused
    }

    private func refreshIndicator() {
        statusItem.button?.title = InputSourceManager.currentDisplayCode()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let convert = NSMenuItem(title: "Convert Last Word", action: #selector(convertClicked), keyEquivalent: "")
        convert.target = self
        menu.addItem(convert)

        let convertSelection = NSMenuItem(title: "Convert Selection", action: #selector(convertSelectionClicked), keyEquivalent: "")
        convertSelection.target = self
        menu.addItem(convertSelection)

        let pause = NSMenuItem(title: "Pause", action: #selector(pauseClicked), keyEquivalent: "")
        pause.target = self
        menu.addItem(pause)
        pauseItem = pause

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(settingsClicked), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(NSMenuItem(title: "Quit keySwitcher", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        return menu
    }

    @objc private func convertClicked() { onConvert?() }
    @objc private func convertSelectionClicked() { onConvertSelection?() }
    @objc private func pauseClicked() { onTogglePause?() }
    @objc private func settingsClicked() { onOpenSettings?() }
}
