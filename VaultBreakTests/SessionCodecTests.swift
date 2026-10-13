import XCTest
@testable import VaultBreak

final class SessionCodecTests: XCTestCase {
    func testDecodeJSONFixtureMatchingGoSessionBlob() throws {
        let json = """
        {
          "version": 1,
          "apiUrl": "https://vault.brainbreaking.com",
          "token": "vb_live_test_token",
          "email": "user@example.com",
          "memberId": "mem-123",
          "updatedAt": "2026-10-12T20:00:00Z"
        }
        """
        let session = try Session.decode(from: Data(json.utf8))

        XCTAssertEqual(session.version, 1)
        XCTAssertEqual(session.apiUrl, "https://vault.brainbreaking.com")
        XCTAssertEqual(session.token, "vb_live_test_token")
        XCTAssertEqual(session.email, "user@example.com")
        XCTAssertEqual(session.memberId, "mem-123")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(
            calendar: calendar,
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2026,
            month: 10,
            day: 12,
            hour: 20,
            minute: 0,
            second: 0
        )
        XCTAssertEqual(session.updatedAt, components.date)
    }

    func testDecodeDefaultsMissingVersionToOne() throws {
        let json = """
        {"apiUrl":"https://api.test","token":"t","email":"e@e.com","memberId":"m"}
        """
        let session = try Session.decode(from: Data(json.utf8))
        XCTAssertEqual(session.version, 1)
    }

    func testDecodeRejectsUnsupportedVersion() {
        let json = """
        {"version": 2, "apiUrl": "https://api.test", "token": "t"}
        """
        XCTAssertThrowsError(try Session.decode(from: Data(json.utf8))) { error in
            XCTAssertEqual(error as? SessionError, SessionError.unsupportedVersion(2))
        }
    }
}
