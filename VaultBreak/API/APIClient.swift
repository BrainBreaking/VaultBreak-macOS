import Foundation

struct APICredentials: Sendable {
    let baseURL: URL
    let token: String

    init(session: Session) throws {
        let trimmed = session.apiUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil, url.host != nil else {
            throw APIClientError.invalidBaseURL
        }
        baseURL = url
        token = session.token
    }
}

/// HTTP client for VaultBreak secret endpoints.
struct APIClient: Sendable {
    let credentials: APICredentials
    let urlSession: URLSession
    let onUnauthorized: (@Sendable () -> Void)?

    init(
        session: Session,
        urlSession: URLSession = .shared,
        onUnauthorized: (@Sendable () -> Void)? = nil
    ) throws {
        credentials = try APICredentials(session: session)
        self.urlSession = urlSession
        self.onUnauthorized = onUnauthorized
    }

    init(
        credentials: APICredentials,
        urlSession: URLSession,
        onUnauthorized: (@Sendable () -> Void)? = nil
    ) {
        self.credentials = credentials
        self.urlSession = urlSession
        self.onUnauthorized = onUnauthorized
    }

    func listSecrets() async throws -> [SecretMetadata] {
        let data = try await performGET(path: "/api/v1/secrets")
        let decoder = Self.makeJSONDecoder()
        do {
            let response = try decoder.decode(ListSecretsResponse.self, from: data)
            return response.secrets
        } catch {
            throw APIClientError.decodingFailed
        }
    }

    func getSecret(id: String) async throws -> SecretWithValue {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw APIClientError.invalidSecretID
        }
        let path = "/api/v1/secrets/\(Self.pathEscaped(trimmed))"
        let data = try await performGET(path: path)
        let decoder = Self.makeJSONDecoder()
        do {
            let response = try decoder.decode(GetSecretResponse.self, from: data)
            return SecretWithValue(metadata: response.secret, value: response.value)
        } catch {
            throw APIClientError.decodingFailed
        }
    }

    // MARK: - Private

    private struct ListSecretsResponse: Decodable {
        let secrets: [SecretMetadata]
    }

    private struct GetSecretResponse: Decodable {
        let secret: SecretMetadata
        let value: String
    }

    private func performGET(path: String) async throws -> Data {
        let url = try Self.endpointURL(base: credentials.baseURL, path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credentials.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.httpError(statusCode: -1, message: nil)
        }

        if http.statusCode == 401 || http.statusCode == 403 {
            onUnauthorized?()
            throw APIClientError.unauthorized
        }

        guard (200 ... 299).contains(http.statusCode) else {
            let message = Self.parseErrorMessage(from: data)
            throw APIClientError.httpError(statusCode: http.statusCode, message: message)
        }

        return data
    }

    private static func endpointURL(base: URL, path: String) throws -> URL {
        guard path.hasPrefix("/") else {
            throw APIClientError.httpError(statusCode: -1, message: nil)
        }
        guard let url = URL(string: path, relativeTo: base)?.absoluteURL else {
            throw APIClientError.invalidBaseURL
        }
        return url
    }

    private static func pathEscaped(_ segment: String) -> String {
        segment.addingPercentEncoding(withAllowedCharacters: Self.pathAllowed) ?? segment
    }

    private static let pathAllowed: CharacterSet = {
        var set = CharacterSet.urlPathAllowed
        set.remove(charactersIn: "/")
        return set
    }()

    private static func parseErrorMessage(from data: Data) -> String? {
        struct APIErrorBody: Decodable {
            let error: String?
        }
        guard let body = try? JSONDecoder().decode(APIErrorBody.self, from: data) else {
            return nil
        }
        return body.error
    }

    private static func makeJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
