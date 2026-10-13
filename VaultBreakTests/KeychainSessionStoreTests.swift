import Security
import XCTest
@testable import VaultBreak

private final class MockKeychainSessionDataSource: KeychainSessionDataSource, @unchecked Sendable {
    var data: Data?
    private(set) var deleteCallCount = 0

    func loadSessionData() -> Data? {
        data
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

    func testClearDeletesSessionData() {
        let mock = MockKeychainSessionDataSource()
        mock.data = Data("{}".utf8)
        let store = KeychainSessionStore(dataSource: mock)

        store.clear()

        XCTAssertEqual(mock.deleteCallCount, 1)
        XCTAssertNil(mock.data)
        XCTAssertNil(store.load())
    }

    func testSystemDataSourceUsesCLIKeychainQueryShape() {
        let source = SystemKeychainSessionDataSource(
            service: KeychainSessionStore.service,
            account: KeychainSessionStore.account
        )
        _ = source.deleteSessionData()
        XCTAssertNil(source.loadSessionData())
    }
}
