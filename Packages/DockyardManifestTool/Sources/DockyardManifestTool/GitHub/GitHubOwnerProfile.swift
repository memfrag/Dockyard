import Foundation

/// Public profile information returned by `GET /users/{login}` (works for both
/// user and organization accounts). We only read the display `name`, which may
/// be null when the owner hasn't set one.
struct GitHubOwnerProfile: Codable, Sendable {
    let name: String?
}
