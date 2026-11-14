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
        XCTAssertEqual(
            VaultBreakURLParser.action(for: URL(string: "vaultbreak://session-updated?result=approved")!),
            .sessionUpdated
        )
    }

    func testAccountDeletedAction() {
        XCTAssertEqual(
            VaultBreakURLParser.action(for: URL(string: "vaultbreak://account-deleted")!),
            .accountDeleted
        )
    }

    func testAuthenticationResultRequiresKnownResultValue() {
        XCTAssertEqual(
            VaultBreakURLParser.authenticationResult(
                for: URL(string: "vaultbreak://session-updated?result=approved")!
            ),
            .approved
        )
        XCTAssertEqual(
            VaultBreakURLParser.authenticationResult(
                for: URL(string: "vaultbreak://session-updated?result=denied")!
            ),
            .denied
        )
        XCTAssertNil(
            VaultBreakURLParser.authenticationResult(
                for: URL(string: "vaultbreak://session-updated?result=unknown")!
            )
        )
        XCTAssertNil(
            VaultBreakURLParser.authenticationResult(
                for: URL(string: "vaultbreak://session-updated")!
            )
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
