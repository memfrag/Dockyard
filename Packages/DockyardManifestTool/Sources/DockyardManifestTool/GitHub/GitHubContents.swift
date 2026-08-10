import Foundation

/// A single entry returned by the GitHub repository contents API
/// (`GET /repos/{owner}/{repo}/contents/{path}`).
struct GitHubContentsEntry: Codable, Sendable {
    let name: String
    let path: String
    let type: String          // "file" | "dir" | "symlink" | "submodule"
    let downloadURL: URL?     // null for non-file entries
    let size: Int
    let sha: String           // git blob hash; changes whenever the content does

    enum CodingKeys: String, CodingKey {
        case name, path, type, size, sha
        case downloadURL = "download_url"
    }
}
