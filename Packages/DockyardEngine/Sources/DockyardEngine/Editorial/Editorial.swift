import Foundation

public struct Editorial: Codable, Equatable, Sendable {

    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let generatedAt: Date
    public let today: TodayEditorial?

    public init(
        schemaVersion: Int = Editorial.currentSchemaVersion,
        generatedAt: Date,
        today: TodayEditorial? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.today = today
    }

    /// Decodes an `Editorial` from JSON `Data`, validating the schema version.
    public static func decode(_ data: Data) throws -> Editorial {
        try EditorialLoader.decode(data)
    }
}

public struct TodayEditorial: Codable, Equatable, Sendable {

    public let title: String
    public let editorsPick: EditorsPickItem?
    public let highlights: [HighlightItem]
    public let sections: [CuratedSection]

    public init(
        title: String,
        editorsPick: EditorsPickItem? = nil,
        highlights: [HighlightItem] = [],
        sections: [CuratedSection] = []
    ) {
        self.title = title
        self.editorsPick = editorsPick
        self.highlights = highlights
        self.sections = sections
    }

    private enum CodingKeys: String, CodingKey {
        case title, editorsPick, highlights, sections
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        editorsPick = try container.decodeIfPresent(EditorsPickItem.self, forKey: .editorsPick)
        highlights = try container.decodeIfPresent([HighlightItem].self, forKey: .highlights) ?? []
        sections = try container.decodeIfPresent([CuratedSection].self, forKey: .sections) ?? []
    }
}

public struct EditorsPickItem: Codable, Equatable, Sendable {

    public let appID: CatalogEntry.ID
    public let category: String
    public let headline: String
    public let description: String
    public let gradient: [String]

    public init(
        appID: CatalogEntry.ID,
        category: String,
        headline: String,
        description: String,
        gradient: [String]
    ) {
        self.appID = appID
        self.category = category
        self.headline = headline
        self.description = description
        self.gradient = gradient
    }
}

public struct HighlightItem: Codable, Equatable, Sendable {

    public let appID: CatalogEntry.ID
    public let category: String
    public let description: String

    public init(appID: CatalogEntry.ID, category: String, description: String) {
        self.appID = appID
        self.category = category
        self.description = description
    }
}

public struct CuratedSection: Codable, Equatable, Sendable {

    public let title: String
    public let subtitle: String?
    public let appIDs: [CatalogEntry.ID]

    public init(title: String, subtitle: String? = nil, appIDs: [CatalogEntry.ID]) {
        self.title = title
        self.subtitle = subtitle
        self.appIDs = appIDs
    }
}
