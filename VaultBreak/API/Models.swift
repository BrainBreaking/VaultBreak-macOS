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

/// Handoff metadata (matches CLI `api.Handoff`; no ciphertext or retrieve token).
struct Handoff: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let title: String
    let message: String?
    let status: String
    let expiresAt: Date
    let oneTime: Bool
    let secretCount: Int
    let secretId: String?
    let createdAt: Date
    let viewedAt: Date?
    let appliedAt: Date?
}

enum HandoffAttention {
    static let pendingStatus = "pending"
    static let handoffsWebURL = URL(string: "https://vault.brainbreaking.com/handoffs")!

    static func needsAttention(handoffs: [Handoff]) -> Bool {
        handoffs.contains { $0.status == pendingStatus }
    }

    static func pendingHandoffs(from handoffs: [Handoff]) -> [Handoff] {
        handoffs.filter { $0.status == pendingStatus }
    }
}

enum APIClientError: Error, Equatable {
    case invalidBaseURL
    case invalidSecretID
    case invalidHandoffID
    case unauthorized
    case httpError(statusCode: Int, message: String?)
    case decodingFailed
}
