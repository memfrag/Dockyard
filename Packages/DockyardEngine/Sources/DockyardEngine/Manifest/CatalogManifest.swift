import Foundation

public struct CatalogManifest: Codable, Equatable, Sendable {

    public static let currentSchemaVersion: Int = 1

    public let schemaVersion: Int
    public let generatedAt: Date
    public let apps: [CatalogEntry]

    /// Browser-based entries, kept in their own key rather than mixed into `apps`.
    ///
    /// Dockyard 1.2.5 and earlier decode `apps` with a hard requirement on
    /// `dmgURL`/`dmgSize`/`version`, and one failing element fails the whole
    /// manifest — so a web app in `apps` would blank the catalog on every copy
    /// already installed. An unknown top-level key is simply ignored instead.
    /// For the same reason `schemaVersion` must stay at 1: shipped clients gate
    /// on exact equality and reject anything else outright.
    public let webApps: [CatalogEntry]

    /// Everything the UI shows, native and web alike.
    public var allApps: [CatalogEntry] { apps + webApps }

    public init(
        schemaVersion: Int = CatalogManifest.currentSchemaVersion,
        generatedAt: Date,
        apps: [CatalogEntry],
        webApps: [CatalogEntry] = []
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.apps = apps
        self.webApps = webApps
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, generatedAt, apps, webApps
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        apps = try container.decode(LenientEntries.self, forKey: .apps).entries
        webApps = try container.decodeIfPresent(LenientEntries.self, forKey: .webApps)?.entries ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(generatedAt, forKey: .generatedAt)
        try container.encode(apps, forKey: .apps)
        // Omitted entirely when empty, so manifests without web apps stay
        // byte-identical to what earlier tool versions produced.
        if !webApps.isEmpty {
            try container.encode(webApps, forKey: .webApps)
        }
    }
}
