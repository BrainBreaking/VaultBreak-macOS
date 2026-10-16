import XCTest
@testable import VaultBreak

final class VaultBreakWebTests: XCTestCase {
    func testOverviewWebURL() {
        XCTAssertEqual(
            VaultBreakWeb.overviewURL.absoluteString,
            "https://vault.brainbreaking.com/overview"
        )
    }

    func testHandoffsWebURL() {
        XCTAssertEqual(
            VaultBreakWeb.handoffsURL.absoluteString,
            "https://vault.brainbreaking.com/handoffs"
        )
        XCTAssertEqual(HandoffAttention.handoffsWebURL, VaultBreakWeb.handoffsURL)
    }
}
