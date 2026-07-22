import Foundation
import Testing
@testable import DockyardManifestTool

@Suite struct AssetSelectorTests {

    private func asset(_ name: String) -> GitHubAsset {
        GitHubAsset(
            name: name,
            size: 100,
            browserDownloadURL: URL(string: "https://example.com/\(name)")!,
            digest: nil
        )
    }

    @Test func patternSelectsMatchingAsset() throws {
        let assets = [asset("Widget-1.0.0.zip"), asset("Widget-1.0.0.dmg"), asset("Other.dmg")]
        let selected = try AssetSelector.select(from: assets, pattern: "^Widget-.*\\.dmg$")
        #expect(selected.name == "Widget-1.0.0.dmg")
    }

    @Test func fallbackPicksFirstDmg() throws {
        let assets = [asset("Widget-1.0.0.zip"), asset("First.dmg"), asset("Second.dmg")]
        let selected = try AssetSelector.select(from: assets, pattern: nil)
        #expect(selected.name == "First.dmg")
    }

    @Test func patternMissThrows() {
        let assets = [asset("Widget-1.0.0.dmg")]
        #expect(throws: AssetSelectorError.self) {
            try AssetSelector.select(from: assets, pattern: "^Gadget-.*\\.dmg$")
        }
    }

    @Test func noDmgThrows() {
        let assets = [asset("Widget-1.0.0.zip")]
        #expect(throws: AssetSelectorError.self) {
            try AssetSelector.select(from: assets, pattern: nil)
        }
    }
}
