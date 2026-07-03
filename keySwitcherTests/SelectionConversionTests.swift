import XCTest
@testable import keySwitcher

/// Character-based conversion (used for selected text) against the real ABC and
/// Russian layouts. Skips if either layout is absent.
final class SelectionConversionTests: XCTestCase {
    private let abc = "com.apple.keylayout.ABC"
    private let russian = "com.apple.keylayout.Russian"

    private func requirePair() throws -> LayoutPair {
        guard InputSourceManager.source(withID: abc) != nil,
              InputSourceManager.source(withID: russian) != nil else {
            throw XCTSkip("ABC and Russian layouts are required for this test")
        }
        return LayoutPair(a: abc, b: russian)
    }

    func testLatinSelectionBecomesRussian() throws {
        let pair = try requirePair()
        let converter = LayoutConverter()
        XCTAssertEqual(converter.convertSelection("ghbdtn", pair: pair), "привет")
    }

    func testRussianSelectionBecomesLatin() throws {
        let pair = try requirePair()
        let converter = LayoutConverter()
        XCTAssertEqual(converter.convertSelection("привет", pair: pair), "ghbdtn")
    }

    func testConversionIsReversible() throws {
        let pair = try requirePair()
        let converter = LayoutConverter()
        let once = converter.convertSelection("ghbdtn", pair: pair)
        XCTAssertEqual(converter.convertSelection(once, pair: pair), "ghbdtn")
    }

    func testCasePreservedByDominantDirection() throws {
        let pair = try requirePair()
        let converter = LayoutConverter()
        // Capital G stays capital: "Ghbdtn" -> "Привет".
        XCTAssertEqual(converter.convertSelection("Ghbdtn", pair: pair), "Привет")
    }

    func testUnmappedCharactersArePreserved() throws {
        let pair = try requirePair()
        let converter = LayoutConverter()
        // Digits and spaces exist identically in both layouts.
        XCTAssertEqual(converter.convertSelection("ghbdtn 123", pair: pair), "привет 123")
    }
}
