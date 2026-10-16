import XCTest
@testable import VaultBreak

final class SessionDisplayTests: XCTestCase {
    func testApiURLHost_extractsHost() {
        XCTAssertEqual(
            SessionDisplay.apiURLHost(from: "https://api.example.com/v1"),
            "api.example.com"
        )
    }

    func testApiURLHost_invalidReturnsPlaceholder() {
        XCTAssertEqual(SessionDisplay.apiURLHost(from: ""), SessionDisplay.placeholder)
        XCTAssertEqual(SessionDisplay.apiURLHost(from: "not-a-url"), SessionDisplay.placeholder)
    }

    func testConsoleEmail_fromSession() {
        let session = Session(apiUrl: "https://x.test", token: "t", email: "user@test.com")
        XCTAssertEqual(SessionDisplay.consoleEmail(from: session), "user@test.com")
    }

    func testConsoleEmail_missingReturnsPlaceholder() {
        XCTAssertEqual(SessionDisplay.consoleEmail(from: nil), SessionDisplay.placeholder)
        let session = Session(apiUrl: "https://x.test", token: "t", email: nil)
        XCTAssertEqual(SessionDisplay.consoleEmail(from: session), SessionDisplay.placeholder)
    }
}
