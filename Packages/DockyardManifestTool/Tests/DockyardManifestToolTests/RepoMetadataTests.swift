import Foundation
import Testing
@testable import DockyardManifestTool

@Suite struct RepoMetadataTests {

    @Test func decodesFullMetadata() throws {
        let json = """
        {
          "schemaVersion": 1,
          "id": "com.acme.widget",
          "displayName": "Widget",
          "category": "Productivity",
          "summary": "Does things.",
          "assetPattern": "^Widget-.*\\\\.dmg$",
          "channel": "Beta"
        }
        """
        let metadata = try RepoMetadata.decode(Data(json.utf8), owner: "acme", repo: "widget")
        #expect(metadata.id == "com.acme.widget")
        #expect(metadata.displayName == "Widget")
        #expect(metadata.assetPattern == "^Widget-.*\\.dmg$")
        #expect(metadata.channel == .beta)
    }

    @Test func decodesMinimalMetadata() throws {
        let json = """
        { "schemaVersion": 1, "id": "com.acme.widget" }
        """
        let metadata = try RepoMetadata.decode(Data(json.utf8), owner: "acme", repo: "widget")
        #expect(metadata.id == "com.acme.widget")
        #expect(metadata.displayName == nil)
        #expect(metadata.channel == nil)
    }

    @Test func rejectsUnsupportedSchemaVersion() {
        let json = """
        { "schemaVersion": 2, "id": "com.acme.widget" }
        """
        #expect {
            try RepoMetadata.decode(Data(json.utf8), owner: "acme", repo: "widget")
        } throws: { error in
            guard case RepoMetadataError.unsupportedSchemaVersion(let version, _, _) = error else {
                return false
            }
            return version == 2
        }
    }

    @Test func rejectsMalformedJSON() {
        #expect {
            try RepoMetadata.decode(Data("not json".utf8), owner: "acme", repo: "widget")
        } throws: { error in
            guard case RepoMetadataError.malformed = error else { return false }
            return true
        }
    }
}
