import Foundation
import Testing
@testable import DockyardEngine

/// Web apps live in their own `webApps` key so that Dockyard 1.2.5 and earlier —
/// which require `dmgURL`/`dmgSize`/`version` on every element of `apps` — keep
/// decoding the catalog exactly as before.
struct WebAppEntryTests {

    private let manifestJSON = """
    {
      "schemaVersion": 1,
      "generatedAt": "2026-08-16T10:00:00Z",
      "apps": [
        {
          "id": "com.apparata.widget",
          "displayName": "Widget",
          "category": "Productivity",
          "summary": "A widget.",
          "iconURL": "https://example.com/widget.png",
          "version": "1.0.0",
          "dmgURL": "https://example.com/Widget-1.0.0.dmg",
          "dmgSize": 123456
        }
      ],
      "webApps": [
        {
          "id": "com.example.webapp",
          "displayName": "Some Web App",
          "category": "Productivity",
          "summary": "Runs in your browser.",
          "iconURL": "https://example.com/web.png",
          "webURL": "https://example.com/app",
          "aboutURL": "https://example.com/about.md",
          "screenshotURLs": ["https://example.com/01.png"]
        }
      ]
    }
    """

    @Test func decodesWebAppsAlongsideNativeApps() throws {
        let manifest = try CatalogLoader.decode(Data(manifestJSON.utf8))

        #expect(manifest.apps.count == 1)
        #expect(manifest.webApps.count == 1)
        #expect(manifest.allApps.map(\.id) == ["com.apparata.widget", "com.example.webapp"])

        let web = try #require(manifest.webApps.first)
        #expect(web.isWebApp)
        #expect(web.webURL == URL(string: "https://example.com/app"))
        #expect(web.version == nil)
        #expect(web.dmgURL == nil)
        #expect(web.dmgSize == nil)
        // Artwork still resolves through the normal caches.
        #expect(web.aboutURL != nil)
        #expect(web.screenshotURLs.count == 1)
    }

    @Test func nativeEntriesAreNotWebApps() throws {
        let manifest = try CatalogLoader.decode(Data(manifestJSON.utf8))
        let native = try #require(manifest.apps.first)
        #expect(!native.isWebApp)
        #expect(native.version == "1.0.0")
        #expect(native.dmgSize == 123_456)
    }

    /// A manifest produced before web apps existed must still decode.
    @Test func manifestWithoutWebAppsKeyDecodes() throws {
        let json = """
        {
          "schemaVersion": 1,
          "generatedAt": "2026-08-16T10:00:00Z",
          "apps": [
            {
              "id": "com.apparata.widget",
              "displayName": "Widget",
              "category": "Productivity",
              "summary": "A widget.",
              "iconURL": "https://example.com/widget.png",
              "version": "1.0.0",
              "dmgURL": "https://example.com/Widget-1.0.0.dmg",
              "dmgSize": 123456
            }
          ]
        }
        """
        let manifest = try CatalogLoader.decode(Data(json.utf8))
        #expect(manifest.webApps.isEmpty)
        #expect(manifest.allApps.count == 1)
    }

    /// The manifest the tool writes must stay byte-compatible for native-only
    /// catalogs: no `webApps` key at all when there are none.
    @Test func encodingOmitsEmptyWebApps() throws {
        let manifest = CatalogManifest(
            generatedAt: Date(timeIntervalSince1970: 0),
            apps: [Self.makeNative()]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = String(decoding: try encoder.encode(manifest), as: UTF8.self)
        #expect(!json.contains("webApps"))
    }

    @Test func webAppRoundTripsThroughEncodeDecode() throws {
        let manifest = CatalogManifest(
            generatedAt: Date(timeIntervalSince1970: 0),
            apps: [Self.makeNative()],
            webApps: [Self.makeWeb()]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoded = try CatalogLoader.decode(try encoder.encode(manifest))

        #expect(decoded == manifest)
        #expect(decoded.webApps.first?.isWebApp == true)
        // A web app must never acquire DMG fields on the way through.
        #expect(decoded.webApps.first?.dmgURL == nil)
    }

    private static func makeNative() -> CatalogEntry {
        CatalogEntry(
            id: "com.apparata.widget",
            displayName: "Widget",
            category: "Productivity",
            summary: "A widget.",
            iconURL: URL(string: "https://example.com/widget.png")!,
            version: "1.0.0",
            dmgURL: URL(string: "https://example.com/Widget-1.0.0.dmg")!,
            dmgSize: 123_456
        )
    }

    private static func makeWeb() -> CatalogEntry {
        CatalogEntry(
            id: "com.example.webapp",
            displayName: "Some Web App",
            category: "Productivity",
            summary: "Runs in your browser.",
            iconURL: URL(string: "https://example.com/web.png")!,
            webURL: URL(string: "https://example.com/app")!
        )
    }
}

/// One malformed entry used to throw away the entire catalog.
struct LenientEntriesTests {

    private func manifest(withAppsBody body: String) -> Data {
        Data("""
        {
          "schemaVersion": 1,
          "generatedAt": "2026-08-16T10:00:00Z",
          "apps": [\(body)]
        }
        """.utf8)
    }

    private let good = """
    {
      "id": "com.apparata.widget",
      "displayName": "Widget",
      "category": "Productivity",
      "summary": "A widget.",
      "iconURL": "https://example.com/widget.png",
      "version": "1.0.0",
      "dmgURL": "https://example.com/Widget-1.0.0.dmg",
      "dmgSize": 123456
    }
    """

    private let secondGood = """
    {
      "id": "com.apparata.other",
      "displayName": "Other",
      "category": "Design",
      "summary": "Another app.",
      "iconURL": "https://example.com/other.png",
      "version": "2.0.0",
      "dmgURL": "https://example.com/Other-2.0.0.dmg",
      "dmgSize": 999
    }
    """

    /// Missing `displayName`, which is still strictly required.
    private let bad = """
    { "id": "com.apparata.broken", "category": "Design" }
    """

    @Test func oneBadEntryDoesNotLoseTheCatalog() throws {
        let decoded = try CatalogLoader.decode(manifest(withAppsBody: "\(good), \(bad), \(secondGood)"))
        #expect(decoded.apps.map(\.id) == ["com.apparata.widget", "com.apparata.other"])
    }

    /// The wrapper must consume exactly one element per failure — a manual skip
    /// would swallow the entry that follows the bad one.
    @Test func entryFollowingABadOneSurvives() throws {
        let decoded = try CatalogLoader.decode(manifest(withAppsBody: "\(bad), \(secondGood)"))
        #expect(decoded.apps.map(\.id) == ["com.apparata.other"])
    }

    @Test func allEntriesBadYieldsEmptyCatalogNotAnError() throws {
        let decoded = try CatalogLoader.decode(manifest(withAppsBody: bad))
        #expect(decoded.apps.isEmpty)
    }

    @Test func malformedTopLevelStillThrows() {
        #expect(throws: EngineError.self) {
            try CatalogLoader.decode(Data(#"{"schemaVersion": 1}"#.utf8))
        }
    }
}
