import Foundation

/// Test seam for secret CRUD operations.
protocol SecretsAPIClient: Sendable {
    func listSecrets() async throws -> [SecretMetadata]
    func getSecret(id: String) async throws -> SecretWithValue
    func createSecret(name: String, value: String) async throws -> SecretMetadata
    func updateSecret(id: String, value: String) async throws -> SecretMetadata
    func deleteSecret(id: String) async throws
}

extension APIClient: SecretsAPIClient {}

/// Test seam for handoff list/revoke operations.
protocol HandoffsAPIClient: Sendable {
    func listHandoffs() async throws -> [Handoff]
    func revokeHandoff(id: String) async throws -> Handoff
}

extension APIClient: HandoffsAPIClient {}
