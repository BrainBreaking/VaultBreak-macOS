import XCTest
@testable import VaultBreak

final class VaultBreakWebTests: XCTestCase {
    func testResolvedBaseURLStaysOnProductionWhenUnset() {
        XCTAssertEqual(
            VaultBreakWeb.resolvedBaseURL(environment: [:]).absoluteString,
            "https://vault.brainbreaking.com"
        )
    }

    func testResolvedBaseURLAcceptsHTTPSOrigin() {
        let url = VaultBreakWeb.resolvedBaseURL(environment: [
            "VAULTBREAK_API_BASE_URL": "https://vaultbreak-git-preview.vercel.app/",
        ])

        XCTAssertEqual(
            url.absoluteString,
            "https://vaultbreak-git-preview.vercel.app"
        )
    }

    func testResolvedBaseURLAcceptsHTTPLoopbackOriginForLocalDebugging() {
        for raw in ["http://localhost:3000/", "http://127.0.0.1:3000"] {
            XCTAssertEqual(
                VaultBreakWeb.resolvedBaseURL(environment: [
                    "VAULTBREAK_API_BASE_URL": raw,
                ]).absoluteString,
                raw.hasSuffix("/") ? String(raw.dropLast()) : raw
            )
        }
    }

    func testResolvedBaseURLRejectsUnsafeOrNonOriginValues() {
        let rejected = [
            "http://preview.vercel.app",
            "http://localhost.example.com:3000",
            "https://user:secret@preview.vercel.app",
            "https://preview.vercel.app/account/delete",
            "https://preview.vercel.app/?next=/",
            "https://preview.vercel.app/#fragment",
            "not a url",
        ]

        for raw in rejected {
            XCTAssertEqual(
                VaultBreakWeb.resolvedBaseURL(environment: [
                    "VAULTBREAK_API_BASE_URL": raw,
                ]),
                VaultBreakWeb.productionBaseURL,
                raw
            )
        }
    }

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

    func testAccountDeletionURLUsesDedicatedPathAndSafeCallback() {
        let components = URLComponents(
            url: VaultBreakWeb.accountDeletionURL,
            resolvingAgainstBaseURL: false
        )

        XCTAssertEqual(components?.path, "/account/delete")
        XCTAssertEqual(
            components?.queryItems?.first(where: { $0.name == "return_to" })?.value,
            "vaultbreak://account-deleted"
        )
    }
}
