import DockyardEngine
import Foundation
import Testing
@testable import DockyardManifestTool

@Suite struct ManifestDiffTests {

    private func entry(
        id: String,
        name: String,
        version: String = "1.0.0",
        summary: String = "An app."
    ) -> CatalogEntry {
        CatalogEntry(
            id: id,
            displayName: name,
            category: "Utilities",
            summary: summary,
            iconURL: URL(string: "https://example.com/icon.png")!,
            version: version,
            dmgURL: URL(string: "https://example.com/\(name)-\(version).dmg")!,
            dmgSize: 1234
        )
    }

    private func manifest(_ entries: [CatalogEntry]) -> CatalogManifest {
        CatalogManifest(generatedAt: Date(timeIntervalSince1970: 0), apps: entries)
    }

    @Test func detectsVersionChange() {
        let previous = PreviousManifest(entries: [entry(id: "a", name: "Alpha", version: "1.0.0")])
        let diff = ManifestDiff.between(
            previous: previous,
            new: manifest([entry(id: "a", name: "Alpha", version: "1.1.0")])
        )
        #expect(diff.versionChanges.count == 1)
        #expect(diff.versionChanges.first?.old == "1.0.0")
        #expect(diff.versionChanges.first?.new == "1.1.0")
        #expect(diff.added.isEmpty)
        #expect(diff.removed.isEmpty)
        #expect(diff.commitMessage == "Update manifest: Alpha 1.1.0")
    }

    @Test func detectsAddedAndRemoved() {
        let previous = PreviousManifest(entries: [entry(id: "a", name: "Alpha")])
        let diff = ManifestDiff.between(
            previous: previous,
            new: manifest([entry(id: "b", name: "Beta")])
        )
        #expect(diff.added == ["Beta"])
        #expect(diff.removed == ["Alpha"])
        #expect(diff.commitMessage == "Update manifest: add Beta, remove Alpha")
    }

    @Test func detectsMetadataOnlyChange() {
        let previous = PreviousManifest(entries: [entry(id: "a", name: "Alpha", summary: "Old.")])
        let diff = ManifestDiff.between(
            previous: previous,
            new: manifest([entry(id: "a", name: "Alpha", summary: "New.")])
        )
        #expect(diff.versionChanges.isEmpty)
        #expect(diff.metadataOnlyChanges == ["Alpha"])
        #expect(diff.commitMessage == "Update manifest: Alpha metadata")
    }

    @Test func identicalManifestsProduceEmptyDiff() {
        let previous = PreviousManifest(entries: [entry(id: "a", name: "Alpha")])
        let diff = ManifestDiff.between(
            previous: previous,
            new: manifest([entry(id: "a", name: "Alpha")])
        )
        #expect(diff.isEmpty)
        #expect(diff.commitMessage == "Update manifest")
    }
}
