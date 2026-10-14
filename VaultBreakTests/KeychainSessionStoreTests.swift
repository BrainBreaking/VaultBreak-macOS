import Security
import XCTest
@testable import VaultBreak

private final class MockKeychainSessionDataSource: KeychainSessionDataSource, @unchecked Sendable {
    var data: Data?
    private(set) var deleteCallCount = 0
    private(set) var saveCallCount = 0

    func loadSessionData() -> Data? {
        data
    }

    func saveSessionData(_ data: Data) -> OSStatus {
        saveCallCount += 1
        self.data = data
        return errSecSuccess
    }

    func deleteSessionData() -> OSStatus {
        deleteCallCount += 1
        data = nil
        return errSecSuccess
    }
}

final class KeychainSessionStoreTests: XCTestCase {
    func testKeychainConstantsMatchCLIContract() {
        XCTAssertEqual(KeychainSessionStore.service, "com.brainbreaking.vaultbreak")
        XCTAssertEqual(KeychainSessionStore.account, "session")
    }

    func testLoadReturnsNilWhenKeychainItemMissing() {
        let mock = MockKeychainSessionDataSource()
        let store = KeychainSessionStore(dataSource: mock)
        XCTAssertNil(store.load())
    }

    func testLoadDecodesSessionFromKeychainBytes() throws {
        let json = """
        {
          "version": 1,
          "apiUrl": "https://vault.brainbreaking.com",
          "token": "vb_live_keychain_test",
          "email": "kc@test.com",
          "memberId": "mem-kc",
          "updatedAt": "2026-10-12T20:00:00Z"
        }
        """
        let mock = MockKeychainSessionDataSource()
        mock.data = Data(json.utf8)
        let store = KeychainSessionStore(dataSource: mock)

        let loaded = try XCTUnwrap(store.load())
        XCTAssertEqual(loaded.token, "vb_live_keychain_test")
        XCTAssertEqual(loaded.apiUrl, "https://vault.brainbreaking.com")
        XCTAssertEqual(loaded.email, "kc@test.com")
        XCTAssertEqual(loaded.memberId, "mem-kc")
    }

    func testLoadDecodesGoKeyringBase64Payload() throws {
        let json = """
        {"version":1,"apiUrl":"https://vault.brainbreaking.com","token":"vb_live_b64","updatedAt":"2026-10-12T20:00:00.282479Z"}
        """
        let wrapped = "go-keyring-base64:" + Data(json.utf8).base64EncodedString()
        let mock = MockKeychainSessionDataSource()
        mock.data = Data(wrapped.utf8)
        let store = KeychainSessionStore(dataSource: mock)

        let loaded = try XCTUnwrap(store.load())
        XCTAssertEqual(loaded.token, "vb_live_b64")
        XCTAssertEqual(loaded.apiUrl, "https://vault.brainbreaking.com")
    }

    func testClearDeletesSessionData() {
        let mock = MockKeychainSessionDataSource()
        mock.data = Data("{}".utf8)
        let store = KeychainSessionStore(dataSource: mock)

        store.clear()

        XCTAssertEqual(mock.deleteCallCount, 1)
        XCTAssertNil(mock.data)
        XCTAssertNil(store.load())
    }

    func testSystemDataSourceReturnsNilForMissingItem() {
        let source = SystemKeychainSessionDataSource(
            service: "com.brainbreaking.vaultbreak.test-query-shape",
            account: "session-test-isolated"
        )
        XCTAssertNil(source.loadSessionData())
    }

    func testDecodeGoKeyringPayloadLeavesPlainJSONUntouched() {
        let json = Data(#"{"version":1}"#.utf8)
        XCTAssertEqual(KeychainSessionStore.decodeGoKeyringPayload(json), json)
    }

    func testSaveRoundTripsSessionWithGoKeyringPrefix() throws {
        let session = Session(
            version: 1,
            apiUrl: "https://vault.brainbreaking.com",
            token: "vb_live_save_test",
            email: "save@test.com",
            memberId: "mem-save",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let mock = MockKeychainSessionDataSource()
        let store = KeychainSessionStore(dataSource: mock)

        try store.save(session)

        XCTAssertEqual(mock.saveCallCount, 1)
        let raw = try XCTUnwrap(mock.data)
        let text = try XCTUnwrap(String(data: raw, encoding: .utf8))
        XCTAssertTrue(text.hasPrefix("go-keyring-base64:"))

        let loaded = try XCTUnwrap(store.load())
        XCTAssertEqual(loaded.token, "vb_live_save_test")
        XCTAssertEqual(loaded.email, "save@test.com")
        XCTAssertEqual(loaded.memberId, "mem-save")
        XCTAssertEqual(loaded.apiUrl, "https://vault.brainbreaking.com")
    }

    func testEncodeGoKeyringPayloadIsDecodable() throws {
        let json = Data(#"{"version":1,"apiUrl":"https://x","token":"t"}"#.utf8)
        let wrapped = KeychainSessionStore.encodeGoKeyringPayload(json)
        let decoded = KeychainSessionStore.decodeGoKeyringPayload(wrapped)
        XCTAssertEqual(decoded, json)
    }
}
