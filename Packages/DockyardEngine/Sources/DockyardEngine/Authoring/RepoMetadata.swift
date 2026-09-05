import Foundation

public enum RepoMetadataError: Error, CustomStringConvertible {
    case unsupportedSchemaVersion(Int, owner: String, repo: String)
    case malformed(owner: String, repo: String, underlying: String)

    public var description: String {
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
///
/// Lives in the engine rather than in the manifest tool because both the tool
/// (which reads it off GitHub) and the app's authoring pane (which writes it to
/// a local checkout) have to agree on the schema.
public struct RepoMetadata: Codable, Sendable, Equatable {

    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let id: String
    public let displayName: String?
    public let category: String?
    public let summary: String?
    public let assetPattern: String?
    public let channel: ReleaseChannel?

    public init(
        schemaVersion: Int = RepoMetadata.currentSchemaVersion,
        id: String,
        displayName: String? = nil,
        category: String? = nil,
        summary: String? = nil,
        assetPattern: String? = nil,
        channel: ReleaseChannel? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.displayName = displayName
        self.category = category
        self.summary = summary
        self.assetPattern = assetPattern
        self.channel = channel
    }

    public static func decode(_ data: Data, owner: String, repo: String) throws -> RepoMetadata {
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
