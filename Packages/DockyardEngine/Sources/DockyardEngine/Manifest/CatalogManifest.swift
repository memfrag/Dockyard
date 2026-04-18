import Foundation

public struct CatalogManifest: Codable, Equatable, Sendable {

    public static let currentSchemaVersion: Int = 1

    public let schemaVersion: Int
    public let generatedAt: Date
    public let apps: [CatalogEntry]

    public init(
        schemaVersion: Int = CatalogManifest.currentSchemaVersion,
        generatedAt: Date,
        apps: [CatalogEntry]
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.apps = apps
    }
}
