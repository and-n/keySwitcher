import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        TabView {
            GeneralTab(settings: settings)
                .tabItem { Label("General", systemImage: "gearshape") }
            HotkeysTab(settings: settings)
                .tabItem { Label("Hotkeys", systemImage: "command") }
            LayoutsTab(settings: settings)
                .tabItem { Label("Layouts", systemImage: "globe") }
        }
        // Grouped forms are List-backed and have no intrinsic height, so the
        // hosting window collapses without an explicit one.
        .frame(width: 460, height: 380)
    }привет как tlfk
}

private struct GeneralTab: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $settings.launchAtLogin)
            Text("keySwitcher runs from the menu bar. Keystrokes stay in memory and are never saved.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .formStyle(.grouped)
    }
}

private struct HotkeysTab: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            Section("Convert last typed word") {
                HotkeyRow(hotkey: $settings.wordHotkey)
            }
            Section("Convert selected text") {
                HotkeyRow(hotkey: $settings.selectionHotkey)
            }
            Text("Pick a preset, or choose Custom and press a shortcut. “Double ⇧” fires when you tap Shift twice quickly.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .formStyle(.grouped)
    }
}

/// One hotkey row: a preset picker plus a recorder shown for the Custom preset.
private struct HotkeyRow: View {
    @Binding var hotkey: Hotkey
    /// Custom mode is UI state, not derivable from the hotkey: choosing Custom
    /// keeps the previous chord active until a new one is recorded.
    @State private var customSelected: Bool

    init(hotkey: Binding<Hotkey>) {
        _hotkey = hotkey
        _customSelected = State(initialValue: !Self.presets.contains { $0.hotkey == hotkey.wrappedValue })
    }

    private static let presets: [(name: String, hotkey: Hotkey)] = [
        ("⌥⇧S", .combo(keyCode: 1, modifiers: [.maskShift, .maskAlternate])),
        ("⌥⇧D", .combo(keyCode: 2, modifiers: [.maskShift, .maskAlternate])),
        ("⌃⌥Space", .combo(keyCode: 49, modifiers: [.maskControl, .maskAlternate])),
        ("Double ⇧", .doubleShift),
    ]

    var body: some View {
        Picker("Shortcut", selection: selection) {
            ForEach(Self.presets, id: \.name) { preset in
                Text(preset.name).tag(preset.name)
            }
            Text(customSelected ? "Custom: \(hotkey.displayString)" : "Custom…").tag("custom")
        }
        if customSelected {
            HStack {
                Text("Custom shortcut")
                Spacer()
                HotkeyRecorderView(hotkey: $hotkey)
                    .frame(width: 140, height: 24)
            }
        }
    }

    private var selection: Binding<String> {
        Binding(
            get: {
                if customSelected { return "custom" }
                return Self.presets.first { $0.hotkey == hotkey }?.name ?? "custom"
            },
            set: { name in
                if let preset = Self.presets.first(where: { $0.name == name }) {
                    customSelected = false
                    hotkey = preset.hotkey
                } else {
                    customSelected = true
                }
            }
        )
    }
}

private struct LayoutsTab: View {
    @ObservedObject var settings: SettingsStore
    private let layouts = InputSourceManager.installedLayoutInfos()

    var body: some View {
        Form {
            if layouts.count <= 2 {
                Section("Layout pair") {
                    Text(layouts.count == 2
                         ? "Automatic: \(layouts[0].name) ↔ \(layouts[1].name)"
                         : "Add a second keyboard layout in System Settings to enable conversion.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Layout pair") {
                    Text("You have more than two layouts. Choose which pair to convert between.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    LayoutPicker(title: "First", selection: $settings.layoutPairA, layouts: layouts)
                    LayoutPicker(title: "Second", selection: $settings.layoutPairB, layouts: layouts)
                    if settings.layoutPairOverride == nil {
                        Text("Pick two different layouts to enable conversion.")
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct LayoutPicker: View {
    let title: String
    @Binding var selection: String
    let layouts: [(id: String, name: String)]

    var body: some View {
        Picker(title, selection: $selection) {
            Text("—").tag("")
            ForEach(layouts, id: \.id) { layout in
                Text(layout.name).tag(layout.id)
            }
        }
    }
}
