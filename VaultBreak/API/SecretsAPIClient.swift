import Foundation

/// Test seam for secret list/get operations.
protocol SecretsAPIClient: Sendable {
    func listSecrets() async throws -> [SecretMetadata]
    func getSecret(id: String) async throws -> SecretWithValue
}

extension APIClient: SecretsAPIClient {}
