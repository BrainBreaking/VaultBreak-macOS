import Foundation

struct DeviceCodeResponse: Codable, Equatable, Sendable {
    var deviceCode: String
    var userCode: String
    var verificationUri: String
    var verificationUriComplete: String? = nil
    var interval: Int
    var expiresIn: Int
}

struct DeviceTokenResponse: Codable, Equatable, Sendable {
    var accessToken: String
    var tokenType: String
}

enum DeviceAuthError: Error, Equatable {
    case authorizationPending
    case slowDown
    case accessDenied
    case expired
    case invalidGrant
    case invalidResponse
    case http(status: Int, message: String?)
}
