import XCTest
@testable import keySwitcher

/// Exercises the real UCKeyTranslate path against the ABC and Russian layouts
/// installed on the machine. Skips gracefully if either layout is absent.
final class LayoutConverterTests: XCTestCase {
    private let abc = "com.apple.keylayout.ABC"
    private let russian = "com.apple.keylayout.Russian"

    // ANSI virtual key codes for g, h, b, d, t, n.
    private let ghbdtnKeyCodes: [CGKeyCode] = [5, 4, 11, 2, 17, 45]

    private func requireLayouts() throws {
        guard InputSourceManager.source(withID: abc) != nil,
              InputSourceManager.source(withID: russian) != nil else {
            throw XCTSkip("ABC and Russian layouts are required for this test")
        }
    }

    func testEnglishKeysConvertToRussianWord() throws {
        try requireLayouts()
        let converter = LayoutConverter()
        let strokes = ghbdtnKeyCodes.map {
            KeyStroke(keyCode: $0, flags: [], inputSourceID: abc)
        }

        // Sanity: the same keys read in ABC spell the Latin source.
        XCTAssertEqual(converter.text(for: strokes, inLayout: abc), "ghbdtn")
        // The point of the app: reinterpreted in Russian they spell "привет".
        XCTAssertEqual(converter.text(for: strokes, inLayout: russian), "привет")
    }

    func testShiftProducesUppercase() throws {
        try requireLayouts()
        let converter = LayoutConverter()
        let stroke = KeyStroke(keyCode: 5, flags: .maskShift, inputSourceID: abc)
        XCTAssertEqual(converter.characters(for: stroke, inLayout: abc), "G")
        XCTAssertEqual(converter.characters(for: stroke, inLayout: russian), "П")
    }

    func testPunctuationMapping() throws {
        try requireLayouts()
        let converter = LayoutConverter()
        // Semicolon key (keycode 41) is "ж" on the Russian layout.
        let stroke = KeyStroke(keyCode: 41, flags: [], inputSourceID: abc)
        XCTAssertEqual(converter.characters(for: stroke, inLayout: abc), ";")
        XCTAssertEqual(converter.characters(for: stroke, inLayout: russian), "ж")
    }
}
