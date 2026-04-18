import Foundation

struct AuthoringEntry: Codable, Sendable {

    struct GitHub: Codable, Sendable {
        let owner: String
        let repo: String
    }

    let id: String                 // must equal CFBundleIdentifier of the built .app
    let displayName: String
    let category: String
    let summary: String
    let iconURL: URL
    let github: GitHub
    let assetPattern: String?      // optional regex; falls back to first *.dmg
}
