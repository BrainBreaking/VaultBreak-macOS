import Foundation

/// OAuth 2.0 device authorization client (mirrors the CLI `DeviceFlow`).
struct DeviceAuthClient: Sendable {
    let baseURL: URL
    private let urlSession: URLSession
    private let sleep: @Sendable (TimeInterval) async throws -> Void
    private let now: @Sendable () -> Date

    init(
        baseURL: URL = VaultBreakWeb.baseURL,
        urlSession: URLSession = .shared,
        sleep: @escaping @Sendable (TimeInterval) async throws -> Void = {
            try await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000))
        },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.sleep = sleep
        self.now = now
    }

    func requestDeviceCode() async throws -> DeviceCodeResponse {
        let request = makeRequest(path: "/api/v1/device/code", body: nil)
        return try await perform(request, as: DeviceCodeResponse.self)
    }

    func requestToken(deviceCode: String) async throws -> DeviceTokenResponse {
        let body = try JSONEncoder().encode(["deviceCode": deviceCode])
        let request = makeRequest(path: "/api/v1/device/token", body: body)
        return try await perform(request, as: DeviceTokenResponse.self)
    }

    /// Polls until approved, denied, or expired. Sleeps `interval` before each poll;
    /// `slow_down` adds 5s to the interval.
    func pollForToken(code: DeviceCodeResponse) async throws -> DeviceTokenResponse {
        var interval = code.interval > 0 ? code.interval : 5
        let deadline = now().addingTimeInterval(TimeInterval(code.expiresIn))
        while true {
            try Task.checkCancellation()
            try await sleep(TimeInterval(interval))
            try Task.checkCancellation()
            if now() > deadline { throw DeviceAuthError.expired }
            do {
                return try await requestToken(deviceCode: code.deviceCode)
            } catch DeviceAuthError.authorizationPending {
                continue
            } catch DeviceAuthError.slowDown {
                interval += 5
            }
        }
    }

    // MARK: - Private

    private func makeRequest(path: String, body: Data?) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw DeviceAuthError.invalidResponse }
        if (200..<300).contains(http.statusCode) {
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw DeviceAuthError.invalidResponse
            }
        }
        let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error
        switch message {
        case "authorization_pending": throw DeviceAuthError.authorizationPending
        case "slow_down": throw DeviceAuthError.slowDown
        case "access_denied": throw DeviceAuthError.accessDenied
        case "expired_token": throw DeviceAuthError.expired
        case "invalid_grant": throw DeviceAuthError.invalidGrant
        default: throw DeviceAuthError.http(status: http.statusCode, message: message)
        }
    }

    private struct ErrorBody: Decodable { let error: String? }
}
