import Carbon.HIToolbox

/// A pair of keyboard layouts between which conversion toggles.
struct LayoutPair: Equatable {
    let a: String
    let b: String

    func contains(_ id: String) -> Bool { id == a || id == b }

    func other(than id: String) -> String? {
        if id == a { return b }
        if id == b { return a }
        return nil
    }
}

/// Wrapper over Text Input Source Services (TIS).
enum InputSourceManager {
    /// ID of the keyboard layout currently used for typing. Uses the
    /// keyboard-layout variant so input methods resolve to their base layout.
    static func currentSourceID() -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue() else {
            return nil
        }
        return sourceID(of: source)
    }

    static func source(withID id: String) -> TISInputSource? {
        let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
        guard let cfList = TISCreateInputSourceList(filter, false)?.takeRetainedValue(),
              let list = cfList as NSArray as? [TISInputSource] else {
            return nil
        }
        return list.first
    }

    static func sourceID(of source: TISInputSource) -> String? {
        stringProperty(source, kTISPropertyInputSourceID)
    }

    /// Enabled, selectable keyboard layouts that expose key layout data
    /// (i.e. exclude emoji palettes and input methods without a layout).
    static func installedLayouts() -> [TISInputSource] {
        guard let cfList = TISCreateInputSourceList(nil, false)?.takeRetainedValue(),
              let list = cfList as NSArray as? [TISInputSource] else {
            return []
        }
        return list.filter(isSelectableKeyboardLayout)
    }

    /// Resolves the working pair: an explicit override if still valid, else
    /// the two installed layouts when exactly two exist, else nil (ambiguous —
    /// the user must choose in settings).
    static func currentPair(override: LayoutPair? = nil) -> LayoutPair? {
        let ids = installedLayouts().compactMap(sourceID(of:))
        if let override, override.contains(where: ids) {
            return override
        }
        if ids.count == 2 {
            return LayoutPair(a: ids[0], b: ids[1])
        }
        return nil
    }

    static func select(id: String) {
        guard let source = source(withID: id) else { return }
        TISSelectInputSource(source)
    }

    /// Short indicator for the menu bar, e.g. "EN" / "RU".
    static func currentDisplayCode() -> String {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return "?"
        }
        if let lang = primaryLanguage(source), !lang.isEmpty {
            return String(lang.prefix(2)).uppercased()
        }
        if let name = stringProperty(source, kTISPropertyLocalizedName) {
            return String(name.prefix(2)).uppercased()
        }
        return "?"
    }

    // MARK: - Property helpers

    private static func isSelectableKeyboardLayout(_ source: TISInputSource) -> Bool {
        guard boolProperty(source, kTISPropertyInputSourceIsSelectCapable),
              boolProperty(source, kTISPropertyInputSourceIsEnabled),
              stringProperty(source, kTISPropertyInputSourceType) == (kTISTypeKeyboardLayout as String) else {
            return false
        }
        return TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) != nil
    }

    private static func stringProperty(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let ptr = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }

    private static func boolProperty(_ source: TISInputSource, _ key: CFString) -> Bool {
        guard let ptr = TISGetInputSourceProperty(source, key) else { return false }
        return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(ptr).takeUnretainedValue())
    }

    private static func primaryLanguage(_ source: TISInputSource) -> String? {
        guard let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) else {
            return nil
        }
        let languages = Unmanaged<CFArray>.fromOpaque(ptr).takeUnretainedValue() as NSArray
        return languages.firstObject as? String
    }
}

private extension LayoutPair {
    func contains(where ids: [String]) -> Bool {
        ids.contains(a) && ids.contains(b)
    }
}
