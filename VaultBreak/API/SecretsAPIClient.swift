import Foundation

/// Test seam for secret list/get operations.
protocol SecretsAPIClient: Sendable {
    func listSecrets() async throws -> [SecretMetadata]
    func getSecret(id: String) async throws -> SecretWithValue
}

extension APIClient: SecretsAPIClient {}

/// Test seam for handoff list/revoke operations.
protocol HandoffsAPIClient: Sendable {
    func listHandoffs() async throws -> [Handoff]
    func revokeHandoff(id: String) async throws -> Handoff
}

extension APIClient: HandoffsAPIClient {}
