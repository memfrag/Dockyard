import DockyardEngine
import Foundation
import Testing
@testable import DockyardManifestTool

@Suite struct PreviousManifestTests {

    private func entry(
        id: String = "com.example.app",
        version: String = "1.0.0",
        dmgURL: String = "https://example.com/App-1.0.0.dmg",
        dmgSize: Int64 = 1234,
        dmgSHA256: String? = "abc123"
    ) -> CatalogEntry {
        CatalogEntry(
            id: id,
            displayName: "App",
            category: "Utilities",
            summary: "An app.",
            iconURL: URL(string: "https://example.com/icon.png")!,
            version: version,
            dmgURL: URL(string: dmgURL)!,
            dmgSize: dmgSize,
            dmgSHA256: dmgSHA256
        )
    }

    @Test func cacheHitWhenURLAndSizeMatch() {
        let previous = PreviousManifest(entries: [entry()])
        let hash = previous.cachedSHA256(
            id: "com.example.app",
            dmgURL: URL(string: "https://example.com/App-1.0.0.dmg")!,
            dmgSize: 1234
        )
        #expect(hash == "abc123")
    }

    @Test func cacheMissWhenURLChanges() {
        let previous = PreviousManifest(entries: [entry()])
        let hash = previous.cachedSHA256(
            id: "com.example.app",
            dmgURL: URL(string: "https://example.com/App-1.1.0.dmg")!,
            dmgSize: 1234
        )
        #expect(hash == nil)
    }

    @Test func cacheMissWhenSizeChanges() {
        let previous = PreviousManifest(entries: [entry()])
        let hash = previous.cachedSHA256(
            id: "com.example.app",
            dmgURL: URL(string: "https://example.com/App-1.0.0.dmg")!,
            dmgSize: 9999
        )
        #expect(hash == nil)
    }

    @Test func cacheMissForUnknownApp() {
        let previous = PreviousManifest(entries: [entry()])
        let hash = previous.cachedSHA256(
            id: "com.example.other",
            dmgURL: URL(string: "https://example.com/App-1.0.0.dmg")!,
            dmgSize: 1234
        )
        #expect(hash == nil)
    }

    @Test func missingFileYieldsEmptyCache() {
        let previous = PreviousManifest.load(from: URL(fileURLWithPath: "/nonexistent/manifest.json"))
        #expect(previous.entriesByID.isEmpty)
    }

    @Test func corruptFileYieldsEmptyCache() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "corrupt-manifest-\(UUID().uuidString).json")
        try Data("not json {".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let previous = PreviousManifest.load(from: url)
        #expect(previous.entriesByID.isEmpty)
    }

    @Test func loadsRealManifest() throws {
        let manifest = CatalogManifest(generatedAt: Date(), apps: [entry()])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let url = FileManager.default.temporaryDirectory
            .appending(path: "manifest-\(UUID().uuidString).json")
        try encoder.encode(manifest).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let previous = PreviousManifest.load(from: url)
        #expect(previous.entriesByID["com.example.app"]?.dmgSHA256 == "abc123")
    }
}
