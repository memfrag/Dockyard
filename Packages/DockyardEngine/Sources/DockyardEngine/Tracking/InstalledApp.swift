import Foundation

public struct InstalledApp: Codable, Equatable, Identifiable, Sendable {

    public let id: CatalogEntry.ID
    public let displayName: String
    public let version: String
    public let bundlePath: URL
    public let installedAt: Date

    public init(
        id: CatalogEntry.ID,
        displayName: String,
        version: String,
        bundlePath: URL,
        installedAt: Date
    ) {
        self.id = id
        self.displayName = displayName
        self.version = version
        self.bundlePath = bundlePath
        self.installedAt = installedAt
    }
}
