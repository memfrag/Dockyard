import Foundation

struct GitHubRelease: Codable, Sendable {
    let tagName: String
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case assets
    }

    /// A best-effort "version string" derived from the tag. Strips leading "v" if present.
    var versionFromTag: String {
        if tagName.hasPrefix("v") {
            return String(tagName.dropFirst())
        }
        return tagName
    }
}
