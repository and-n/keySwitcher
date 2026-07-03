import AppKit

/// Owns the NSStatusItem in the menu bar. In stage 3 the icon becomes the
/// current input source indicator; for now it is a static keyboard glyph.
final class StatusBarController {
    private let statusItem: NSStatusItem

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "keySwitcher")
        }
        statusItem.menu = makeMenu()
    }

    /// Dimmed icon while the Accessibility permission is missing.
    func setActive(_ active: Bool) {
        statusItem.button?.appearsDisabled = !active
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "keySwitcher", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit keySwitcher", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        return menu
    }
}
