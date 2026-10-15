import XCTest
@testable import VaultBreak

// MARK: - URLProtocol mock (private to this file)

private final class MockDeviceAuthURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
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
    config.protocolClasses = [MockDeviceAuthURLProtocol.self]
    return URLSession(configuration: config)
}

private func bodyData(_ request: URLRequest) -> Data? {
    if let body = request.httpBody, !body.isEmpty { return body }
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

private func jsonResponse(_ request: URLRequest, status: Int, _ json: String) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(
        url: request.url!,
        statusCode: status,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
    )!
    return (response, Data(json.utf8))
}

/// Virtual clock so poll tests never actually wait.
private final class FakeClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = Date(timeIntervalSince1970: 1_000_000)
    private var _sleeps: [TimeInterval] = []

    var sleeps: [TimeInterval] { lock.withLock { _sleeps } }
    func now() -> Date { lock.withLock { current } }
    func sleep(_ seconds: TimeInterval) {
        lock.withLock {
            _sleeps.append(seconds)
            current = current.addingTimeInterval(seconds)
        }
    }
}

private let codeJSON = """
{"deviceCode":"dev-123","userCode":"ABCD-EFGH","verificationUri":"https://vault.example.com/device","interval":5,"expiresIn":600}
"""

final class DeviceAuthClientTests: XCTestCase {
    private let base = URL(string: "https://vault.example.com")!

    override func tearDown() {
        MockDeviceAuthURLProtocol.requestHandler = nil
        super.tearDown()
    }

    private func makeClient(clock: FakeClock = FakeClock()) -> (DeviceAuthClient, FakeClock) {
        let client = DeviceAuthClient(
            baseURL: base,
            urlSession: makeMockURLSession(),
            sleep: { clock.sleep($0) },
            now: { clock.now() }
        )
        return (client, clock)
    }

    private func sampleCode(interval: Int = 5, expiresIn: Int = 600) -> DeviceCodeResponse {
        DeviceCodeResponse(
            deviceCode: "dev-123",
            userCode: "ABCD-EFGH",
            verificationUri: "https://vault.example.com/device",
            interval: interval,
            expiresIn: expiresIn
        )
    }

    func testDefaultBaseURLIsProduction() {
        let client = DeviceAuthClient()
        XCTAssertEqual(client.baseURL, VaultBreakWeb.baseURL)
        XCTAssertEqual(client.baseURL.absoluteString, "https://vault.brainbreaking.com")
    }

    func testRequestDeviceCodePostsAndDecodes() async throws {
        MockDeviceAuthURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://vault.example.com/api/v1/device/code")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            return jsonResponse(request, status: 200, codeJSON)
        }
        let (client, _) = makeClient()
        let code = try await client.requestDeviceCode()
        XCTAssertEqual(code.deviceCode, "dev-123")
        XCTAssertEqual(code.userCode, "ABCD-EFGH")
        XCTAssertEqual(code.verificationUri, "https://vault.example.com/device")
        XCTAssertEqual(code.interval, 5)
        XCTAssertEqual(code.expiresIn, 600)
    }

    func testRequestDeviceCodeHTTPErrorSurfacesMessage() async {
        MockDeviceAuthURLProtocol.requestHandler = { request in
            jsonResponse(request, status: 500, #"{"error":"boom"}"#)
        }
        let (client, _) = makeClient()
        do {
            _ = try await client.requestDeviceCode()
            XCTFail("expected error")
        } catch let error as DeviceAuthError {
            XCTAssertEqual(error, .http(status: 500, message: "boom"))
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testRequestTokenSuccessSendsDeviceCode() async throws {
        MockDeviceAuthURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/device/token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            let body = bodyData(request).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: String] }
            XCTAssertEqual(body?["deviceCode"], "dev-123")
            return jsonResponse(request, status: 200, #"{"accessToken":"tok-abc","tokenType":"bearer"}"#)
        }
        let (client, _) = makeClient()
        let token = try await client.requestToken(deviceCode: "dev-123")
        XCTAssertEqual(token.accessToken, "tok-abc")
        XCTAssertEqual(token.tokenType, "bearer")
    }

    func testRequestTokenMapsErrorCodes() async {
        let cases: [(String, DeviceAuthError)] = [
            ("authorization_pending", .authorizationPending),
            ("slow_down", .slowDown),
            ("access_denied", .accessDenied),
            ("expired_token", .expired),
            ("invalid_grant", .invalidGrant),
        ]
        for (code, expected) in cases {
            MockDeviceAuthURLProtocol.requestHandler = { request in
                jsonResponse(request, status: 400, #"{"error":"\#(code)"}"#)
            }
            let (client, _) = makeClient()
            do {
                _ = try await client.requestToken(deviceCode: "dev-123")
                XCTFail("expected error for \(code)")
            } catch let error as DeviceAuthError {
                XCTAssertEqual(error, expected, code)
            } catch {
                XCTFail("unexpected \(error)")
            }
        }
    }

    func testPollSleepsIntervalBeforeEachPollAndReturnsAfterPending() async throws {
        var calls = 0
        MockDeviceAuthURLProtocol.requestHandler = { request in
            calls += 1
            if calls < 3 {
                return jsonResponse(request, status: 400, #"{"error":"authorization_pending"}"#)
            }
            return jsonResponse(request, status: 200, #"{"accessToken":"tok-xyz","tokenType":"bearer"}"#)
        }
        let (client, clock) = makeClient()
        let token = try await client.pollForToken(code: sampleCode())
        XCTAssertEqual(token.accessToken, "tok-xyz")
        XCTAssertEqual(calls, 3)
        XCTAssertEqual(clock.sleeps, [5, 5, 5])
    }

    func testPollSlowDownAddsFiveSeconds() async throws {
        var calls = 0
        MockDeviceAuthURLProtocol.requestHandler = { request in
            calls += 1
            switch calls {
            case 1: return jsonResponse(request, status: 400, #"{"error":"slow_down"}"#)
            case 2: return jsonResponse(request, status: 400, #"{"error":"authorization_pending"}"#)
            default: return jsonResponse(request, status: 200, #"{"accessToken":"t","tokenType":"bearer"}"#)
            }
        }
        let (client, clock) = makeClient()
        _ = try await client.pollForToken(code: sampleCode())
        XCTAssertEqual(clock.sleeps, [5, 10, 10])
    }

    func testPollThrowsAccessDenied() async {
        MockDeviceAuthURLProtocol.requestHandler = { request in
            jsonResponse(request, status: 400, #"{"error":"access_denied"}"#)
        }
        let (client, _) = makeClient()
        do {
            _ = try await client.pollForToken(code: sampleCode())
            XCTFail("expected error")
        } catch let error as DeviceAuthError {
            XCTAssertEqual(error, .accessDenied)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testPollThrowsExpiredFromServer() async {
        MockDeviceAuthURLProtocol.requestHandler = { request in
            jsonResponse(request, status: 400, #"{"error":"expired_token"}"#)
        }
        let (client, _) = makeClient()
        do {
            _ = try await client.pollForToken(code: sampleCode())
            XCTFail("expected error")
        } catch let error as DeviceAuthError {
            XCTAssertEqual(error, .expired)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testPollStopsWhenDeadlinePasses() async {
        var calls = 0
        MockDeviceAuthURLProtocol.requestHandler = { request in
            calls += 1
            return jsonResponse(request, status: 400, #"{"error":"authorization_pending"}"#)
        }
        let (client, clock) = makeClient()
        do {
            // t=5 poll, t=10 poll, t=15 > deadline(12) -> expired without a third request.
            _ = try await client.pollForToken(code: sampleCode(interval: 5, expiresIn: 12))
            XCTFail("expected error")
        } catch let error as DeviceAuthError {
            XCTAssertEqual(error, .expired)
        } catch {
            XCTFail("unexpected \(error)")
        }
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(clock.sleeps, [5, 5, 5])
    }

    func testPollPropagatesCancellation() async {
        MockDeviceAuthURLProtocol.requestHandler = { request in
            jsonResponse(request, status: 400, #"{"error":"authorization_pending"}"#)
        }
        let client = DeviceAuthClient(
            baseURL: base,
            urlSession: makeMockURLSession(),
            sleep: { _ in throw CancellationError() },
            now: { Date() }
        )
        do {
            _ = try await client.pollForToken(code: sampleCode())
            XCTFail("expected cancellation")
        } catch is CancellationError {
            // expected
        } catch {
            XCTFail("unexpected \(error)")
        }
    }
}
