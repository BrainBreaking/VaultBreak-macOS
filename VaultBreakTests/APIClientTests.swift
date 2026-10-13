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

final class MockSecretsURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeMockURLSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockSecretsURLProtocol.self]
    return URLSession(configuration: config)
}

/// URLSession may deliver POST bodies via `httpBodyStream` instead of `httpBody` to URLProtocol.
private func urlRequestBodyData(_ request: URLRequest) -> Data? {
    if let body = request.httpBody, !body.isEmpty {
        return body
    }
    guard let stream = request.httpBodyStream else { return nil }
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while stream.hasBytesAvailable {
        let read = stream.read(&buffer, maxLength: buffer.count)
        if read <= 0 { break }
        data.append(buffer, count: read)
    }
    return data.isEmpty ? nil : data
}

private func sampleSession() -> Session {
    Session(apiUrl: "https://vault.example.com", token: "test-bearer-token", email: "u@example.com")
}

@MainActor
final class APIClientTests: XCTestCase {
    override func tearDown() {
        MockSecretsURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testListSecrets200() async throws {
        let listJSON = """
        {
          "secrets": [
            {
              "id": "sec-1",
              "name": "prod-db",
              "labels": { "env": "prod" },
              "createdAt": "2026-01-15T10:00:00Z",
              "updatedAt": "2026-01-16T12:00:00Z"
            }
          ]
        }
        """
        MockSecretsURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/v1/secrets")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-bearer-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(listJSON.utf8))
        }

        let client = try APIClient(session: sampleSession(), urlSession: makeMockURLSession())
        let secrets = try await client.listSecrets()

        XCTAssertEqual(secrets.count, 1)
        XCTAssertEqual(secrets[0].id, "sec-1")
        XCTAssertEqual(secrets[0].name, "prod-db")
        XCTAssertEqual(secrets[0].labels?["env"], "prod")
    }

    func testGetSecret200() async throws {
        let getJSON = """
        {
          "secret": {
            "id": "sec-42",
            "name": "api-key",
            "createdAt": "2026-02-01T08:00:00Z",
            "updatedAt": "2026-02-01T08:00:00Z"
          },
          "value": "super-secret-value"
        }
        """
        MockSecretsURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/v1/secrets/sec-42")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(getJSON.utf8))
        }

        let client = try APIClient(session: sampleSession(), urlSession: makeMockURLSession())
        let secret = try await client.getSecret(id: "sec-42")

        XCTAssertEqual(secret.metadata.id, "sec-42")
        XCTAssertEqual(secret.metadata.name, "api-key")
        XCTAssertEqual(secret.value, "super-secret-value")
    }

    func testUnauthorized401InvokesClearCallback() async throws {
        let unauthorizedCalled = expectation(description: "onUnauthorized")
        MockSecretsURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let client = try APIClient(
            session: sampleSession(),
            urlSession: makeMockURLSession(),
            onUnauthorized: { unauthorizedCalled.fulfill() }
        )

        do {
            _ = try await client.listSecrets()
            XCTFail("Expected unauthorized error")
        } catch let error as APIClientError {
            XCTAssertEqual(error, .unauthorized)
        }

        await fulfillment(of: [unauthorizedCalled], timeout: 2)
    }

    func testMakeAPIClientClearsSessionOn401() async throws {
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

        MockSecretsURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 403,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let client = try model.makeAPIClient(urlSession: makeMockURLSession())
        do {
            _ = try await client.listSecrets()
            XCTFail("Expected unauthorized")
        } catch let error as APIClientError {
            XCTAssertEqual(error, .unauthorized)
        }

        let deadline = Date().addingTimeInterval(2)
        while model.isSignedIn, Date() < deadline {
            await Task.yield()
        }

        XCTAssertFalse(model.isSignedIn)
        XCTAssertEqual(mock.deleteCallCount, 1)
    }

    func testListHandoffs200() async throws {
        let listJSON = """
        {
          "handoffs": [
            {
              "id": "ho-1",
              "title": "Deploy keys",
              "status": "pending",
              "expiresAt": "2026-05-01T00:00:00Z",
              "oneTime": true,
              "secretCount": 1,
              "secretId": "sec-1",
              "createdAt": "2026-04-01T00:00:00Z"
            }
          ]
        }
        """
        MockSecretsURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/v1/handoffs")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-bearer-token")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(listJSON.utf8))
        }

        let client = try APIClient(session: sampleSession(), urlSession: makeMockURLSession())
        let handoffs = try await client.listHandoffs()

        XCTAssertEqual(handoffs.count, 1)
        XCTAssertEqual(handoffs[0].id, "ho-1")
        XCTAssertEqual(handoffs[0].status, "pending")
    }

    func testRevokeHandoff200() async throws {
        let revokeJSON = """
        {
          "handoff": {
            "id": "ho-revoke",
            "title": "Old share",
            "status": "revoked",
            "expiresAt": "2026-05-01T00:00:00Z",
            "oneTime": false,
            "secretCount": 0,
            "createdAt": "2026-04-01T00:00:00Z"
          }
        }
        """
        MockSecretsURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/handoffs/ho-revoke")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            let bodyData = urlRequestBodyData(request)
            let json = try XCTUnwrap(bodyData.flatMap { try JSONSerialization.jsonObject(with: $0) as? [String: String] })
            XCTAssertEqual(json["action"], "revoke")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(revokeJSON.utf8))
        }

        let client = try APIClient(session: sampleSession(), urlSession: makeMockURLSession())
        let handoff = try await client.revokeHandoff(id: "ho-revoke")

        XCTAssertEqual(handoff.id, "ho-revoke")
        XCTAssertEqual(handoff.status, "revoked")
    }

    func testRevokeHandoffEmptyIDThrows() async throws {
        let client = try APIClient(session: sampleSession(), urlSession: makeMockURLSession())
        do {
            _ = try await client.revokeHandoff(id: "   ")
            XCTFail("Expected invalidHandoffID")
        } catch let error as APIClientError {
            XCTAssertEqual(error, .invalidHandoffID)
        }
    }
}
