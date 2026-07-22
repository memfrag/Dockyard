import DockyardEngine
import Foundation

enum RepoMetadataError: Error, CustomStringConvertible {
    case unsupportedSchemaVersion(Int, owner: String, repo: String)
    case malformed(owner: String, repo: String, underlying: String)

    var description: String {
        switch self {
        case .unsupportedSchemaVersion(let version, let owner, let repo):
            return "\(owner)/\(repo): .dockyard/dockyard.json has unsupported schemaVersion \(version) (expected \(RepoMetadata.currentSchemaVersion))"
        case .malformed(let owner, let repo, let underlying):
            return "\(owner)/\(repo): .dockyard/dockyard.json is unreadable: \(underlying)"
        }
    }
}

/// App metadata published by the app repo itself at `.dockyard/dockyard.json`,
/// making the repo self-describing so the authoring config can shrink to just
/// `{ "github": { "owner": ..., "repo": ... } }`.
struct RepoMetadata: Codable, Sendable {

    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let id: String
    let displayName: String?
    let category: String?
    let summary: String?
    let assetPattern: String?
    let channel: ReleaseChannel?

    static func decode(_ data: Data, owner: String, repo: String) throws -> RepoMetadata {
        let metadata: RepoMetadata
        do {
            metadata = try JSONDecoder().decode(RepoMetadata.self, from: data)
        } catch {
            throw RepoMetadataError.malformed(owner: owner, repo: repo, underlying: String(describing: error))
        }
        guard metadata.schemaVersion == currentSchemaVersion else {
            throw RepoMetadataError.unsupportedSchemaVersion(metadata.schemaVersion, owner: owner, repo: repo)
        }
        return metadata
    }
}
