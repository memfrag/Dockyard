import Foundation
import Testing
@testable import DockyardManifestTool

@Suite struct AssetPatternSuggesterTests {

    @Test func generalizesVersionRun() {
        #expect(AssetPatternSuggester.suggest(assetName: "Automata-1.0.0.dmg") == "^Automata-.*\\.dmg$")
    }

    @Test func suggestedPatternMatchesFutureVersions() throws {
        let pattern = try #require(AssetPatternSuggester.suggest(assetName: "Automata-1.0.0.dmg"))
        let regex = try NSRegularExpression(pattern: pattern)
        for name in ["Automata-1.0.1.dmg", "Automata-2.3.dmg"] {
            let range = NSRange(name.startIndex..<name.endIndex, in: name)
            #expect(regex.firstMatch(in: name, range: range) != nil, "\(pattern) should match \(name)")
        }
        let other = "Other-1.0.1.dmg"
        let otherRange = NSRange(other.startIndex..<other.endIndex, in: other)
        #expect(regex.firstMatch(in: other, range: otherRange) == nil)
    }

    @Test func noVersionRunReturnsNil() {
        #expect(AssetPatternSuggester.suggest(assetName: "Widget.dmg") == nil)
    }

    @Test func nonDmgReturnsNil() {
        #expect(AssetPatternSuggester.suggest(assetName: "Widget-1.0.0.zip") == nil)
    }
}
