import XCTest
@testable import VaultBreak

private struct MockSecretsAPIClient: SecretsAPIClient {
    var listResult: Result<[SecretMetadata], Error> = .success([])
    var getResult: Result<SecretWithValue, Error> = .failure(APIClientError.decodingFailed)

    func listSecrets() async throws -> [SecretMetadata] {
        try listResult.get()
    }

    func getSecret(id: String) async throws -> SecretWithValue {
        try getResult.get()
    }
}

private final class MockPasteboard: PasteboardProviding {
    var string: String?

    func setString(_ value: String) { string = value }
    func clearString() { string = nil }
    func currentString() -> String? { string }
}

private final class MockClipboardScheduler: ClipboardClearScheduling {
    func schedule(after delay: TimeInterval, block: @escaping () -> Void) {}
    func cancelScheduled() {}
}

@MainActor
final class PopoverSecretsViewModelTests: XCTestCase {
    private let sampleDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func metadata(name: String, id: String = UUID().uuidString) -> SecretMetadata {
        SecretMetadata(id: id, name: name, labels: nil, createdAt: sampleDate, updatedAt: sampleDate)
    }

    func testLoadSecretsPopulatesList() async {
        let items = [metadata(name: "Alpha"), metadata(name: "Beta")]
        let client = MockSecretsAPIClient(listResult: .success(items))
        let vm = PopoverSecretsViewModel(
            clientFactory: { client },
            clipboard: ClipboardClearService(pasteboard: MockPasteboard(), scheduler: MockClipboardScheduler())
        )

        await vm.loadSecrets()

        XCTAssertEqual(vm.secrets.count, 2)
        XCTAssertNil(vm.loadError)
    }

    func testSearchFiltersCaseInsensitive() async {
        let a = metadata(name: "Production-DB", id: "a")
        let b = metadata(name: "Staging", id: "b")
        let client = MockSecretsAPIClient(listResult: .success([a, b]))
        let vm = PopoverSecretsViewModel(
            clientFactory: { client },
            clipboard: ClipboardClearService(pasteboard: MockPasteboard(), scheduler: MockClipboardScheduler())
        )
        await vm.loadSecrets()

        vm.searchText = "prod"
        XCTAssertEqual(vm.filteredSecrets.map(\.id), ["a"])

        vm.searchText = "STAGING"
        XCTAssertEqual(vm.filteredSecrets.map(\.id), ["b"])
    }

    func testCopySecretWritesClipboardAndSetsCopiedID() async {
        let meta = metadata(name: "Key", id: "secret-1")
        let secret = SecretWithValue(metadata: meta, value: "hunter2")
        let client = MockSecretsAPIClient(
            listResult: .success([meta]),
            getResult: .success(secret)
        )
        let pasteboard = MockPasteboard()
        let vm = PopoverSecretsViewModel(
            clientFactory: { client },
            clipboard: ClipboardClearService(pasteboard: pasteboard, scheduler: MockClipboardScheduler(), clearAfterSeconds: 30)
        )

        await vm.copySecret(id: "secret-1")

        XCTAssertEqual(pasteboard.string, "hunter2")
        XCTAssertEqual(vm.copiedSecretID, "secret-1")
        XCTAssertNil(vm.copyError)
    }

    func testLoadUnauthorizedSetsError() async {
        let client = MockSecretsAPIClient(listResult: .failure(APIClientError.unauthorized))
        let vm = PopoverSecretsViewModel(
            clientFactory: { client },
            clipboard: ClipboardClearService(pasteboard: MockPasteboard(), scheduler: MockClipboardScheduler())
        )

        await vm.loadSecrets()

        XCTAssertTrue(vm.secrets.isEmpty)
        XCTAssertEqual(vm.loadError, "Session expired — sign in again")
    }
}
