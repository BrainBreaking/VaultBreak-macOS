import XCTest
@testable import VaultBreak

private func sampleHandoff(
    id: String = "ho-1",
    title: String = "Share DB creds",
    status: String = HandoffAttention.pendingStatus
) -> Handoff {
    let date = ISO8601DateFormatter().date(from: "2026-03-01T12:00:00Z")!
    return Handoff(
        id: id,
        title: title,
        message: nil,
        status: status,
        expiresAt: date,
        oneTime: true,
        secretCount: 1,
        secretId: "sec-1",
        createdAt: date,
        viewedAt: nil,
        appliedAt: nil
    )
}

@MainActor
private final class CreateMockHandoffsClient: HandoffsAPIClient, @unchecked Sendable {
    var listResult: Result<[Handoff], Error> = .success([])
    var createResult: Result<CreateHandoffResult, Error> = .failure(APIClientError.invalidHandoffID)
    private(set) var createCallCount = 0
    private(set) var lastCreateTitle: String?
    private(set) var lastCreateSecretID: String?
    private(set) var lastCreateRecipientEmail: String?

    func listHandoffs() async throws -> [Handoff] {
        try listResult.get()
    }

    func revokeHandoff(id: String) async throws -> Handoff {
        throw APIClientError.invalidHandoffID
    }

    func createHandoff(
        title: String,
        secretID: String,
        expiresAt: Date?,
        oneTime: Bool,
        recipientEmail: String?
    ) async throws -> CreateHandoffResult {
        createCallCount += 1
        lastCreateTitle = title
        lastCreateSecretID = secretID
        lastCreateRecipientEmail = recipientEmail
        return try createResult.get()
    }
}

@MainActor
final class ConsoleHandoffsViewModelTests: XCTestCase {
    func testCreateHandoffSuccessSetsRetrieveURLAndRefreshesList() async {
        let client = CreateMockHandoffsClient()
        let created = sampleHandoff(id: "ho-new", title: "Prod share")
        let retrieveURL = URL(string: "https://vault.example.com/h/token-abc")!
        client.createResult = .success(
            CreateHandoffResult(
                handoff: created,
                retrieveToken: "token-abc",
                retrieveURL: retrieveURL
            )
        )
        client.listResult = .success([created])

        let viewModel = ConsoleHandoffsViewModel(clientFactory: { client })
        let ok = await viewModel.createHandoff(
            title: "Prod share",
            secretID: "sec-1",
            expiresAt: nil,
            oneTime: true
        )

        XCTAssertTrue(ok)
        XCTAssertEqual(viewModel.lastCreatedRetrieveURL, retrieveURL)
        XCTAssertEqual(viewModel.handoffs.count, 1)
        XCTAssertEqual(viewModel.handoffs[0].id, "ho-new")
        XCTAssertEqual(client.createCallCount, 1)
        XCTAssertNil(viewModel.createError)
    }

    func testCreateHandoffEmptyTitleDoesNotCallAPI() async {
        let client = CreateMockHandoffsClient()
        let viewModel = ConsoleHandoffsViewModel(clientFactory: { client })

        let ok = await viewModel.createHandoff(
            title: "   ",
            secretID: "sec-1",
            expiresAt: nil,
            oneTime: true
        )

        XCTAssertFalse(ok)
        XCTAssertEqual(viewModel.createError, "Title is required.")
        XCTAssertEqual(client.createCallCount, 0)
        XCTAssertNil(viewModel.lastCreatedRetrieveURL)
    }

    func testCreateHandoffMissingClientSetsError() async {
        let viewModel = ConsoleHandoffsViewModel(clientFactory: { nil })

        let ok = await viewModel.createHandoff(
            title: "Share",
            secretID: "sec-1",
            expiresAt: nil,
            oneTime: true
        )

        XCTAssertFalse(ok)
        XCTAssertEqual(viewModel.createError, "Sign in to create a handoff.")
        XCTAssertNil(viewModel.lastCreatedRetrieveURL)
    }

    func testAcknowledgeCreatedHandoffClearsURL() async {
        let client = CreateMockHandoffsClient()
        let retrieveURL = URL(string: "https://vault.example.com/h/tok")!
        client.createResult = .success(
            CreateHandoffResult(
                handoff: sampleHandoff(),
                retrieveToken: "tok",
                retrieveURL: retrieveURL
            )
        )
        client.listResult = .success([sampleHandoff()])

        let viewModel = ConsoleHandoffsViewModel(clientFactory: { client })
        _ = await viewModel.createHandoff(
            title: "Share",
            secretID: "sec-1",
            expiresAt: nil,
            oneTime: true
        )
        XCTAssertEqual(viewModel.lastCreatedRetrieveURL, retrieveURL)

        viewModel.acknowledgeCreatedHandoff()
        XCTAssertNil(viewModel.lastCreatedRetrieveURL)
        XCTAssertNil(viewModel.lastCreatedEmailNote)
        XCTAssertNil(viewModel.createError)
    }

    func testCreateHandoffWithRecipientEmailSetsEmailedNote() async {
        let client = CreateMockHandoffsClient()
        let retrieveURL = URL(string: "https://vault.example.com/h/tok")!
        client.createResult = .success(
            CreateHandoffResult(
                handoff: sampleHandoff(),
                retrieveToken: "tok",
                retrieveURL: retrieveURL,
                emailSent: true
            )
        )
        client.listResult = .success([sampleHandoff()])

        let viewModel = ConsoleHandoffsViewModel(clientFactory: { client })
        let ok = await viewModel.createHandoff(
            title: "Share",
            secretID: "sec-1",
            expiresAt: nil,
            oneTime: true,
            recipientEmail: "partner@example.com"
        )

        XCTAssertTrue(ok)
        XCTAssertEqual(client.lastCreateRecipientEmail, "partner@example.com")
        XCTAssertEqual(viewModel.lastCreatedEmailNote, "Link emailed to partner@example.com.")
    }

    func testCreateHandoffInvalidEmailDoesNotCallAPI() async {
        let client = CreateMockHandoffsClient()
        let viewModel = ConsoleHandoffsViewModel(clientFactory: { client })

        let ok = await viewModel.createHandoff(
            title: "Share",
            secretID: "sec-1",
            expiresAt: nil,
            oneTime: true,
            recipientEmail: "not-an-email"
        )

        XCTAssertFalse(ok)
        XCTAssertEqual(viewModel.createError, "Enter a valid email address.")
        XCTAssertEqual(client.createCallCount, 0)
    }

    func testCreateHandoffEmailNotSentSetsFailureNote() async {
        let client = CreateMockHandoffsClient()
        let retrieveURL = URL(string: "https://vault.example.com/h/tok")!
        client.createResult = .success(
            CreateHandoffResult(
                handoff: sampleHandoff(),
                retrieveToken: "tok",
                retrieveURL: retrieveURL,
                emailSent: false,
                emailReason: "provider off"
            )
        )
        client.listResult = .success([sampleHandoff()])

        let viewModel = ConsoleHandoffsViewModel(clientFactory: { client })
        let ok = await viewModel.createHandoff(
            title: "Share",
            secretID: "sec-1",
            expiresAt: nil,
            oneTime: true,
            recipientEmail: "partner@example.com"
        )

        XCTAssertTrue(ok)
        XCTAssertEqual(
            viewModel.lastCreatedEmailNote,
            "Couldn’t email partner@example.com: provider off"
        )
    }
}
