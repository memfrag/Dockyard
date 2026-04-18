import Foundation

public struct CatalogEntry: Codable, Equatable, Identifiable, Sendable {

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

    public init(
        id: ID,
        displayName: String,
        category: String,
        summary: String,
        iconURL: URL,
        version: String,
        dmgURL: URL,
        dmgSize: Int64,
        dmgSHA256: String? = nil
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
    }
}
