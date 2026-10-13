import Foundation

/// Secret metadata returned by the VaultBreak API (matches CLI `api.Secret`).
struct SecretMetadata: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let name: String
    let labels: [String: String]?
    let createdAt: Date
    let updatedAt: Date
}

struct SecretWithValue: Equatable, Sendable {
    let metadata: SecretMetadata
    let value: String
}

enum APIClientError: Error, Equatable {
    case invalidBaseURL
    case invalidSecretID
    case unauthorized
    case httpError(statusCode: Int, message: String?)
    case decodingFailed
}
