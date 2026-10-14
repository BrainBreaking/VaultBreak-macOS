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
        // Go's encoding/json emits RFC3339 with fractional seconds (e.g. …58.443571Z).
        // Foundation's .iso8601 strategy rejects those and would leave the tray signed out.
        decoder.dateDecodingStrategy = .custom(decodeISO8601Date)
        let session = try decoder.decode(Session.self, from: data)
        guard session.version == 1 else {
            throw SessionError.unsupportedVersion(session.version)
        }
        return session
    }

    func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            try container.encode(formatter.string(from: date))
        }
        return try encoder.encode(self)
    }

    private static func decodeISO8601Date(from decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: string) {
            return date
        }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: string) {
            return date
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Invalid ISO8601 date: \(string)"
        )
    }
}

enum SessionError: Error, Equatable {
    case unsupportedVersion(Int)
}

enum KeychainSessionError: Error, Equatable {
    case saveFailed(OSStatus)
    case clearFailed(OSStatus)
}
