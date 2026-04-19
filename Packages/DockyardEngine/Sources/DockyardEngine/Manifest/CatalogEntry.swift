import Foundation

public struct CatalogEntry: Codable, Equatable, Hashable, Identifiable, Sendable {

    public typealias ID = String

    /// The installed app's `CFBundleIdentifier`. This is the join key used across
    /// installed state, disk-based recovery, and install-time validation.
    public let id: ID

    public let displayName: String
    public let category: String
    public let summary: String
    public let iconURL: URL
    public let version: String
    public let dmgURL: URL
    public let dmgSize: Int64
    public let dmgSHA256: String?
    public let github: GitHubRepo?
    public let channel: ReleaseChannel

    public init(
        id: ID,
        displayName: String,
        category: String,
        summary: String,
        iconURL: URL,
        version: String,
        dmgURL: URL,
        dmgSize: Int64,
        dmgSHA256: String? = nil,
        github: GitHubRepo? = nil,
        channel: ReleaseChannel = .release
    ) {
        self.id = id
        self.displayName = displayName
        self.category = category
        self.summary = summary
        self.iconURL = iconURL
        self.version = version
        self.dmgURL = dmgURL
        self.dmgSize = dmgSize
        self.dmgSHA256 = dmgSHA256
        self.github = github
        self.channel = channel
    }

    private enum CodingKeys: String, CodingKey {
        case id, displayName, category, summary, iconURL, version
        case dmgURL, dmgSize, dmgSHA256, github, channel
    }

    /// Custom decoder so that older manifests that predate the `channel` field
    /// still decode successfully and default to the `Release` channel.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        category = try container.decode(String.self, forKey: .category)
        summary = try container.decode(String.self, forKey: .summary)
        iconURL = try container.decode(URL.self, forKey: .iconURL)
        version = try container.decode(String.self, forKey: .version)
        dmgURL = try container.decode(URL.self, forKey: .dmgURL)
        dmgSize = try container.decode(Int64.self, forKey: .dmgSize)
        dmgSHA256 = try container.decodeIfPresent(String.self, forKey: .dmgSHA256)
        github = try container.decodeIfPresent(GitHubRepo.self, forKey: .github)
        channel = try container.decodeIfPresent(ReleaseChannel.self, forKey: .channel) ?? .release
    }
}
