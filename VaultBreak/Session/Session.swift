import Foundation

struct Session: Codable, Equatable {
    var version: Int
    var apiUrl: String
    var token: String
    var email: String?
    var memberId: String?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case version
        case apiUrl
        case token
        case email
        case memberId
        case updatedAt
    }

    init(
        version: Int = 1,
        apiUrl: String,
        token: String,
        email: String? = nil,
        memberId: String? = nil,
        updatedAt: Date? = nil
    ) {
        self.version = version == 0 ? 1 : version
        self.apiUrl = apiUrl
        self.token = token
        self.email = email
        self.memberId = memberId
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawVersion = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        version = rawVersion == 0 ? 1 : rawVersion
        apiUrl = try container.decode(String.self, forKey: .apiUrl)
        token = try container.decode(String.self, forKey: .token)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        memberId = try container.decodeIfPresent(String.self, forKey: .memberId)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    static func decode(from data: Data) throws -> Session {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let session = try decoder.decode(Session.self, from: data)
        guard session.version == 1 else {
            throw SessionError.unsupportedVersion(session.version)
        }
        return session
    }
}

enum SessionError: Error, Equatable {
    case unsupportedVersion(Int)
}
