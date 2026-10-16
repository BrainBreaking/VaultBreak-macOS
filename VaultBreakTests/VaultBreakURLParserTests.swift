import XCTest
@testable import VaultBreak

final class VaultBreakURLParserTests: XCTestCase {
    func testOpenAction() {
        XCTAssertEqual(
            VaultBreakURLParser.action(for: URL(string: "vaultbreak://open")!),
            .open
        )
        XCTAssertEqual(
            VaultBreakURLParser.action(for: URL(string: "vaultbreak://open?foo=1")!),
            .open
        )
    }

    func testSessionUpdatedAction() {
        XCTAssertEqual(
            VaultBreakURLParser.action(for: URL(string: "vaultbreak://session-updated")!),
            .sessionUpdated
        )
    }

    func testCaseInsensitiveSchemeAndHost() {
        XCTAssertEqual(
            VaultBreakURLParser.action(for: URL(string: "VaultBreak://OPEN")!),
            .open
        )
        XCTAssertEqual(
            VaultBreakURLParser.action(for: URL(string: "vaultbreak://Session-Updated")!),
            .sessionUpdated
        )
    }

    func testUnknownHostReturnsNil() {
        XCTAssertNil(VaultBreakURLParser.action(for: URL(string: "vaultbreak://unknown")!))
    }

    func testWrongSchemeReturnsNil() {
        XCTAssertNil(VaultBreakURLParser.action(for: URL(string: "https://open")!))
    }
}
