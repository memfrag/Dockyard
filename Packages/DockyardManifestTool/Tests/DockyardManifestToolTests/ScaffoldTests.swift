import Foundation
import Testing
@testable import DockyardManifestTool

@Suite struct ScaffoldTests {

    @Test func scaffoldIsValidRepoMetadata() throws {
        let json = DockyardManifestTool.Add.scaffoldJSON(
            bundleID: "com.acme.widget",
            name: "Widget",
            assetName: "Widget-1.2.3.dmg"
        )
        let metadata = try RepoMetadata.decode(Data(json.utf8), owner: "acme", repo: "widget")
        #expect(metadata.id == "com.acme.widget")
        #expect(metadata.displayName == "Widget")
        #expect(metadata.category == "TODO")
        #expect(metadata.summary == "TODO")
        #expect(metadata.assetPattern == "^Widget-.*\\.dmg$")
    }

    @Test func scaffoldWithoutVersionedAssetOmitsPattern() throws {
        let json = DockyardManifestTool.Add.scaffoldJSON(
            bundleID: "com.acme.widget",
            name: "Widget",
            assetName: "Widget.dmg"
        )
        let metadata = try RepoMetadata.decode(Data(json.utf8), owner: "acme", repo: "widget")
        #expect(metadata.assetPattern == nil)
    }
}
