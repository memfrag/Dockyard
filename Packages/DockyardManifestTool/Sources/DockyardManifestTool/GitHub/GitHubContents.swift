import Foundation

/// A single entry returned by the GitHub repository contents API
/// (`GET /repos/{owner}/{repo}/contents/{path}`).
struct GitHubContentsEntry: Codable, Sendable {
    let name: String
    let path: String
    let type: String          // "file" | "dir" | "symlink" | "submodule"
    let downloadURL: URL?     // null for non-file entries
    let size: Int

    enum CodingKeys: String, CodingKey {
        case name, path, type, size
        case downloadURL = "download_url"
    }
}
