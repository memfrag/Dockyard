import Foundation
import Testing
@testable import DockyardEngine

struct EditorialLoaderTests {

    @Test func decodesValidEditorial() throws {
        let json = """
        {
          "schemaVersion": 1,
          "generatedAt": "2026-04-18T15:30:00Z",
          "today": {
            "title": "On the shelf this week",
            "editorsPick": {
              "appID": "com.apparata.docs",
              "category": "Editor's Pick",
              "headline": "Docs 4.1 makes the wiki disappear.",
              "description": "Offline-first, keyboard-native.",
              "gradient": ["#383D57", "#1A1F34"]
            },
            "highlights": [
              {
                "appID": "com.apparata.deploy",
                "category": "New to Dockyard",
                "description": "A thin client over the deploy pipeline."
              }
            ],
            "sections": [
              {
                "title": "For your team",
                "subtitle": "Picked for you",
                "appIDs": ["com.a", "com.b"]
              }
            ]
          }
        }
        """
        let editorial = try EditorialLoader.decode(Data(json.utf8))
        #expect(editorial.schemaVersion == 1)
        #expect(editorial.today?.title == "On the shelf this week")
        #expect(editorial.today?.editorsPick?.appID == "com.apparata.docs")
        #expect(editorial.today?.editorsPick?.gradient == ["#383D57", "#1A1F34"])
        #expect(editorial.today?.highlights.count == 1)
        #expect(editorial.today?.sections.count == 1)
        #expect(editorial.today?.sections[0].appIDs == ["com.a", "com.b"])
    }

    @Test func defaultsOptionalArraysToEmpty() throws {
        let json = """
        {
          "schemaVersion": 1,
          "generatedAt": "2026-04-18T15:30:00Z",
          "today": {
            "title": "Quiet week"
          }
        }
        """
        let editorial = try EditorialLoader.decode(Data(json.utf8))
        #expect(editorial.today?.editorsPick == nil)
        #expect(editorial.today?.highlights == [])
        #expect(editorial.today?.sections == [])
    }

    @Test func todaySectionIsOptional() throws {
        let json = """
        {
          "schemaVersion": 1,
          "generatedAt": "2026-04-18T15:30:00Z"
        }
        """
        let editorial = try EditorialLoader.decode(Data(json.utf8))
        #expect(editorial.today == nil)
    }

    @Test func rejectsUnknownSchemaVersion() throws {
        let json = """
        {
          "schemaVersion": 2,
          "generatedAt": "2026-04-18T15:30:00Z"
        }
        """
        #expect(throws: EngineError.self) {
            try EditorialLoader.decode(Data(json.utf8))
        }
    }

    @Test func surfacesDecodeErrors() {
        let json = "{ not valid json"
        #expect(throws: EngineError.self) {
            try EditorialLoader.decode(Data(json.utf8))
        }
    }
}
