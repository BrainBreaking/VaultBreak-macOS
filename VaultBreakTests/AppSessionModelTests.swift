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

@MainActor
final class AppSessionModelTests: XCTestCase {
    func testInitialLoadSignedOutWhenKeychainEmpty() {
        let mock = MockKeychainSessionDataSource()
        let model = AppSessionModel(store: KeychainSessionStore(dataSource: mock))

        XCTAssertFalse(model.isSignedIn)
        XCTAssertNil(model.accountLabel)
    }

    func testReloadReflectsSignedInSession() throws {
        let json = """
        {
          "version": 1,
          "apiUrl": "https://vault.example.com",
          "token": "secret-token",
          "email": "user@example.com"
        }
        """
        let mock = MockKeychainSessionDataSource()
        mock.data = Data(json.utf8)
        let model = AppSessionModel(store: KeychainSessionStore(dataSource: mock))

        XCTAssertTrue(model.isSignedIn)
        XCTAssertEqual(model.accountLabel, "user@example.com")
    }

    func testAccountLabelFallbackWhenEmailMissing() throws {
        let json = """
        {
          "version": 1,
          "apiUrl": "https://vault.example.com",
          "token": "secret-token"
        }
        """
        let mock = MockKeychainSessionDataSource()
        mock.data = Data(json.utf8)
        let model = AppSessionModel(store: KeychainSessionStore(dataSource: mock))

        XCTAssertEqual(model.accountLabel, "Signed in")
    }

    func testReloadAfterKeychainCleared() throws {
        let json = """
        {
          "version": 1,
          "apiUrl": "https://vault.example.com",
          "token": "secret-token",
          "email": "user@example.com"
        }
        """
        let mock = MockKeychainSessionDataSource()
        mock.data = Data(json.utf8)
        let model = AppSessionModel(store: KeychainSessionStore(dataSource: mock))
        XCTAssertTrue(model.isSignedIn)

        mock.data = nil
        model.reload()

        XCTAssertFalse(model.isSignedIn)
    }

    func testClearSessionRemovesKeychainAndState() throws {
        let json = """
        {
          "version": 1,
          "apiUrl": "https://vault.example.com",
          "token": "secret-token"
        }
        """
        let mock = MockKeychainSessionDataSource()
        mock.data = Data(json.utf8)
        let model = AppSessionModel(store: KeychainSessionStore(dataSource: mock))

        model.clearSession()

        XCTAssertFalse(model.isSignedIn)
        XCTAssertEqual(mock.deleteCallCount, 1)
        XCTAssertNil(mock.data)
    }

    func testHandleOpenURLSessionUpdatedReloads() throws {
        let json = """
        {
          "version": 1,
          "apiUrl": "https://vault.example.com",
          "token": "secret-token",
          "email": "fresh@example.com"
        }
        """
        let mock = MockKeychainSessionDataSource()
        let model = AppSessionModel(store: KeychainSessionStore(dataSource: mock))
        XCTAssertFalse(model.isSignedIn)

        mock.data = Data(json.utf8)
        model.handleOpenURL(URL(string: "vaultbreak://session-updated")!)

        XCTAssertTrue(model.isSignedIn)
        XCTAssertEqual(model.accountLabel, "fresh@example.com")
    }

    func testHandleOpenURLOpenIsNoOpUntilM5() {
        let mock = MockKeychainSessionDataSource()
        let model = AppSessionModel(store: KeychainSessionStore(dataSource: mock))

        model.handleOpenURL(URL(string: "vaultbreak://open")!)

        XCTAssertFalse(model.isSignedIn)
    }

    func testHandleOpenURLIgnoresUnknownHosts() {
        let mock = MockKeychainSessionDataSource()
        let model = AppSessionModel(store: KeychainSessionStore(dataSource: mock))

        model.handleOpenURL(URL(string: "vaultbreak://unknown")!)
        model.handleOpenURL(URL(string: "https://example.com")!)

        XCTAssertFalse(model.isSignedIn)
    }
}
