import XCTest
@testable import keySwitcher

final class KeyBufferTests: XCTestCase {
    private func stroke(_ keyCode: CGKeyCode) -> KeyStroke {
        KeyStroke(keyCode: keyCode, flags: [], inputSourceID: "test")
    }

    private let space: CGKeyCode = 49

    func testLastWordReturnsTailAfterSpace() {
        let buffer = KeyBuffer()
        // "ab cd"
        [1, 2, space, 3, 4].forEach { buffer.append(stroke($0)) }
        XCTAssertEqual(buffer.lastWord().map(\.keyCode), [3, 4])
    }

    func testLastWordWithoutSeparatorReturnsEverything() {
        let buffer = KeyBuffer()
        [1, 2, 3].forEach { buffer.append(stroke($0)) }
        XCTAssertEqual(buffer.lastWord().map(\.keyCode), [1, 2, 3])
    }

    func testLastWordIncludesTrailingSpace() {
        let buffer = KeyBuffer()
        // "ab " — a trailing separator stays attached so replacement keeps it.
        [1, 2, space].forEach { buffer.append(stroke($0)) }
        XCTAssertEqual(buffer.lastWord().map(\.keyCode), [1, 2, space])
    }

    func testBackspaceRemovesLastStroke() {
        let buffer = KeyBuffer()
        [1, 2, 3].forEach { buffer.append(stroke($0)) }
        buffer.removeLast()
        XCTAssertEqual(buffer.all().map(\.keyCode), [1, 2])
    }

    func testResetClearsBuffer() {
        let buffer = KeyBuffer()
        [1, 2, 3].forEach { buffer.append(stroke($0)) }
        buffer.reset()
        XCTAssertTrue(buffer.isEmpty)
    }

    func testCapacityIsBounded() {
        let buffer = KeyBuffer()
        for _ in 0..<250 { buffer.append(stroke(1)) }
        XCTAssertLessThanOrEqual(buffer.all().count, 100)
    }
}
