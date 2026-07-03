import SwiftUI

/// First-launch screen explaining why the Accessibility permission is needed.
struct OnboardingView: View {
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "keyboard")
                    .font(.system(size: 34))
                    .foregroundStyle(.tint)
                Text("keySwitcher needs the Accessibility permission")
                    .font(.title3.bold())
            }

            Text("""
            Without it, macOS does not allow reading keystrokes or replacing the text you typed in the wrong layout.

            Everything happens locally on your Mac: keystrokes are kept only in memory (the last few dozen), never written to disk, never sent anywhere. The source code is open.
            """)
            .fixedSize(horizontal: false, vertical: true)

            Text("System Settings → Privacy & Security → Accessibility → enable keySwitcher. This window closes automatically once the permission is granted.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Open System Settings") { openSettings() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}

#Preview {
    OnboardingView(openSettings: {})
}
