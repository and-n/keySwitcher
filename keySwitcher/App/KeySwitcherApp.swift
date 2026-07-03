import SwiftUI

@main
struct KeySwitcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Settings window arrives in stage 5; the scene keeps the SwiftUI
        // lifecycle happy for an LSUIElement app with no regular windows.
        Settings {
            EmptyView()
        }
    }
}
