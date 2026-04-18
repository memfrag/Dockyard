import Foundation

struct AuthoringConfig: Codable, Sendable {
    let apps: [AuthoringEntry]

    static func load(from url: URL) throws -> AuthoringConfig {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AuthoringConfig.self, from: data)
    }
}
