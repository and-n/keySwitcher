import Carbon.HIToolbox

/// Wrapper over Text Input Source Services (TIS). Stage 2 adds layout-pair
/// resolution and switching; stage 3 adds change observation.
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
        guard let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
            return nil
        }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }
}
