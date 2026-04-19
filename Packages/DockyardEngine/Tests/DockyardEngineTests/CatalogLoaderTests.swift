import Foundation
import Testing
@testable import DockyardEngine

struct CatalogLoaderTests {

    @Test func decodesValidManifest() throws {
        let json = """
        {
          "schemaVersion": 1,
          "generatedAt": "2026-04-18T15:30:00Z",
          "apps": [
            {
              "id": "com.apparata.widget",
              "displayName": "Widget",
              "category": "Productivity",
              "summary": "A widget.",
              "iconURL": "https://example.com/widget.png",
              "version": "1.0.0",
              "dmgURL": "https://example.com/Widget-1.0.0.dmg",
              "dmgSize": 123456,
              "dmgSHA256": "deadbeef"
            }
          ]
        }
        """
        let manifest = try CatalogLoader.decode(Data(json.utf8))
        #expect(manifest.schemaVersion == 1)
        #expect(manifest.apps.count == 1)
        #expect(manifest.apps[0].id == "com.apparata.widget")
        #expect(manifest.apps[0].dmgSHA256 == "deadbeef")
        #expect(manifest.apps[0].github == nil)
        #expect(manifest.apps[0].channel == .release)
    }

    @Test func decodesChannel() throws {
        let json = """
        {
          "schemaVersion": 1,
          "generatedAt": "2026-04-18T15:30:00Z",
          "apps": [
            {
              "id": "com.apparata.widget",
              "displayName": "Widget",
              "category": "Productivity",
              "summary": "A widget.",
              "iconURL": "https://example.com/widget.png",
              "version": "1.0.0",
              "dmgURL": "https://example.com/Widget-1.0.0.dmg",
              "dmgSize": 123456,
              "channel": "Beta"
            }
          ]
        }
        """
        let manifest = try CatalogLoader.decode(Data(json.utf8))
        #expect(manifest.apps[0].channel == .beta)
    }

    @Test func decodesGitHubRepo() throws {
        let json = """
        {
          "schemaVersion": 1,
          "generatedAt": "2026-04-18T15:30:00Z",
          "apps": [
            {
              "id": "com.apparata.widget",
              "displayName": "Widget",
              "category": "Productivity",
              "summary": "A widget.",
              "iconURL": "https://example.com/widget.png",
              "version": "1.0.0",
              "dmgURL": "https://example.com/Widget-1.0.0.dmg",
              "dmgSize": 123456,
              "github": { "owner": "apparata", "repo": "widget-mac" }
            }
          ]
        }
        """
        let manifest = try CatalogLoader.decode(Data(json.utf8))
        #expect(manifest.apps[0].github?.owner == "apparata")
        #expect(manifest.apps[0].github?.repo == "widget-mac")
        #expect(manifest.apps[0].github?.url.absoluteString == "https://github.com/apparata/widget-mac")
    }

    @Test func rejectsUnknownSchemaVersion() throws {
        let json = """
        {
          "schemaVersion": 2,
          "generatedAt": "2026-04-18T15:30:00Z",
          "apps": []
        }
        """
        #expect(throws: EngineError.self) {
            try CatalogLoader.decode(Data(json.utf8))
        }
    }

    @Test func surfacesDecodeErrors() {
        let json = "{ not valid json"
        #expect(throws: EngineError.self) {
            try CatalogLoader.decode(Data(json.utf8))
        }
    }

    @Test func optionalDMGSHA256() throws {
        let json = """
        {
          "schemaVersion": 1,
          "generatedAt": "2026-04-18T15:30:00Z",
          "apps": [
            {
              "id": "a",
              "displayName": "A",
              "category": "X",
              "summary": "",
              "iconURL": "https://example.com/a.png",
              "version": "1.0",
              "dmgURL": "https://example.com/a.dmg",
              "dmgSize": 1
            }
          ]
        }
        """
        let manifest = try CatalogLoader.decode(Data(json.utf8))
        #expect(manifest.apps[0].dmgSHA256 == nil)
    }
}
