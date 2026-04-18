import Foundation

struct GitHubAsset: Codable, Sendable {
    let name: String
    let size: Int64
    let browserDownloadURL: URL
    let digest: String?           // introduced recently; often of the form "sha256:abc..."

    enum CodingKeys: String, CodingKey {
        case name
        case size
        case browserDownloadURL = "browser_download_url"
        case digest
    }
}
