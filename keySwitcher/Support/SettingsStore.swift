import Combine
import Foundation

/// Single source of truth for user settings. Persists to UserDefaults and
/// posts `didChange` so the running core can re-apply bindings live.
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    static let didChange = Notification.Name("keySwitcher.settingsDidChange")

    @Published var wordHotkey: Hotkey {
        didSet { save(wordHotkey, forKey: Keys.wordHotkey); notify() }
    }
    @Published var selectionHotkey: Hotkey {
        didSet { save(selectionHotkey, forKey: Keys.selectionHotkey); notify() }
    }
    /// Explicit layout pair when more than two layouts are installed.
    /// Empty strings mean "not set" (automatic when exactly two exist).
    @Published var layoutPairA: String {
        didSet { defaults.set(layoutPairA, forKey: Keys.layoutPairA); notify() }
    }
    @Published var layoutPairB: String {
        didSet { defaults.set(layoutPairB, forKey: Keys.layoutPairB); notify() }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            LaunchAtLogin.set(launchAtLogin)
        }
    }

    var layoutPairOverride: LayoutPair? {
        guard !layoutPairA.isEmpty, !layoutPairB.isEmpty, layoutPairA != layoutPairB else {
            return nil
        }
        return LayoutPair(a: layoutPairA, b: layoutPairB)
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let wordHotkey = "wordHotkey"
        static let selectionHotkey = "selectionHotkey"
        static let layoutPairA = "layoutPairA"
        static let layoutPairB = "layoutPairB"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Assign via the backing storage so didSet doesn't fire during load.
        _wordHotkey = Published(initialValue: Self.load(forKey: Keys.wordHotkey, from: defaults) ?? .optionShiftS)
        _selectionHotkey = Published(initialValue: Self.load(forKey: Keys.selectionHotkey, from: defaults) ?? .optionShiftD)
        _layoutPairA = Published(initialValue: defaults.string(forKey: Keys.layoutPairA) ?? "")
        _layoutPairB = Published(initialValue: defaults.string(forKey: Keys.layoutPairB) ?? "")
        _launchAtLogin = Published(initialValue: LaunchAtLogin.isEnabled)
    }

    private func notify() {
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }

    private func save(_ hotkey: Hotkey, forKey key: String) {
        guard let data = try? JSONEncoder().encode(hotkey) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load(forKey key: String, from defaults: UserDefaults) -> Hotkey? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Hotkey.self, from: data)
    }
}
