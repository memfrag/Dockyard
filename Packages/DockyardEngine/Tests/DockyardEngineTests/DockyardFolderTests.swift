import Foundation
import Testing
@testable import DockyardEngine

struct DockyardFolderTests {

    private func makeRepo() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "repo-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func write(_ contents: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url)
    }

    @Test func loadingARepoWithNoDockyardFolderYieldsEmpty() throws {
        let repo = try makeRepo()
        defer { try? FileManager.default.removeItem(at: repo) }

        let folder = try DockyardFolder.load(from: repo)

        #expect(folder.isEmpty)
        #expect(folder.metadata == nil)
        #expect(folder.screenshotURLs.isEmpty)
    }

    @Test func loadsExistingMetadataAboutIconAndScreenshots() throws {
        let repo = try makeRepo()
        defer { try? FileManager.default.removeItem(at: repo) }

        try write("""
        {
          "schemaVersion": 1,
          "id": "com.acme.widget",
          "displayName": "Widget",
          "category": "Productivity",
          "summary": "A widget.",
          "assetPattern": "^Widget-.*\\\\.dmg$",
          "channel": "Beta"
        }
        """, to: repo.appending(path: ".dockyard/dockyard.json"))
        try write("About the widget.\n", to: repo.appending(path: ".dockyard/about.md"))
        try write("png", to: repo.appending(path: ".dockyard/AppIcon.png"))
        try write("png", to: repo.appending(path: ".dockyard/screenshots/02.png"))
        try write("png", to: repo.appending(path: ".dockyard/screenshots/01.png"))
        try write("ignore me", to: repo.appending(path: ".dockyard/screenshots/README.md"))

        let folder = try DockyardFolder.load(from: repo)

        #expect(!folder.isEmpty)
        #expect(folder.metadata?.id == "com.acme.widget")
        #expect(folder.metadata?.category == "Productivity")
        #expect(folder.metadata?.channel == .beta)
        #expect(folder.metadata?.assetPattern == "^Widget-.*\\.dmg$")
        #expect(folder.about == "About the widget.\n")
        #expect(folder.iconURL != nil)
        // Sorted, and non-image files excluded, exactly as the manifest build does.
        #expect(folder.screenshotURLs.map(\.lastPathComponent) == ["01.png", "02.png"])
    }

    /// Discarding a malformed file would mean silently overwriting hand-written
    /// metadata on the next save.
    @Test func malformedMetadataThrowsRatherThanBeingIgnored() throws {
        let repo = try makeRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        try write("{ not json", to: repo.appending(path: ".dockyard/dockyard.json"))

        #expect(throws: RepoMetadataError.self) {
            try DockyardFolder.load(from: repo)
        }
    }

    @Test func savingCreatesTheFolderFromNothing() throws {
        let repo = try makeRepo()
        defer { try? FileManager.default.removeItem(at: repo) }

        var folder = try DockyardFolder.load(from: repo)
        folder.metadata = RepoMetadata(
            id: "com.acme.widget",
            displayName: "Widget",
            category: "Productivity",
            summary: "A widget.",
            assetPattern: "^Widget-.*\\.dmg$"
        )
        folder.about = "About the widget."
        try folder.save()

        let reloaded = try DockyardFolder.load(from: repo)
        #expect(reloaded.metadata == folder.metadata)
        #expect(reloaded.about == "About the widget.\n")
    }

    @Test func savedJSONIsReadableAndSkipsBlankFields() throws {
        let repo = try makeRepo()
        defer { try? FileManager.default.removeItem(at: repo) }

        var folder = try DockyardFolder.load(from: repo)
        folder.metadata = RepoMetadata(id: "com.acme.widget", displayName: "Widget", category: "  ", summary: nil)
        try folder.save()

        let text = try String(contentsOf: folder.metadataURL, encoding: .utf8)
        #expect(text.hasPrefix("{\n  \"schemaVersion\": 1,\n  \"id\": \"com.acme.widget\""))
        #expect(text.contains("\"displayName\": \"Widget\""))
        #expect(!text.contains("category"), "a blank field should be omitted, not written as an empty string")
        #expect(!text.contains("summary"))
        // The catalog reads this back; it must stay valid JSON.
        _ = try RepoMetadata.decode(Data(text.utf8), owner: "acme", repo: "widget")
    }

    /// An escaped regex must survive the round trip, since assetPattern is the
    /// field most likely to contain backslashes.
    @Test func assetPatternSurvivesRoundTrip() throws {
        let repo = try makeRepo()
        defer { try? FileManager.default.removeItem(at: repo) }

        var folder = try DockyardFolder.load(from: repo)
        folder.metadata = RepoMetadata(id: "com.acme.widget", assetPattern: "^Widget-.*\\.dmg$")
        try folder.save()

        #expect(try DockyardFolder.load(from: repo).metadata?.assetPattern == "^Widget-.*\\.dmg$")
    }

    @Test func clearingAboutRemovesTheFile() throws {
        let repo = try makeRepo()
        defer { try? FileManager.default.removeItem(at: repo) }

        var folder = try DockyardFolder.load(from: repo)
        folder.metadata = RepoMetadata(id: "com.acme.widget")
        folder.about = "Something."
        try folder.save()
        #expect(FileManager.default.fileExists(atPath: folder.aboutURL.path))

        folder.about = ""
        try folder.save()
        #expect(!FileManager.default.fileExists(atPath: folder.aboutURL.path))
    }

    /// Saving a form must never disturb the binary assets beside it.
    @Test func savingLeavesIconAndScreenshotsAlone() throws {
        let repo = try makeRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        try write("the icon", to: repo.appending(path: ".dockyard/AppIcon.png"))
        try write("a shot", to: repo.appending(path: ".dockyard/screenshots/01.png"))

        var folder = try DockyardFolder.load(from: repo)
        folder.metadata = RepoMetadata(id: "com.acme.widget")
        try folder.save()

        #expect(try String(contentsOf: folder.defaultIconURL, encoding: .utf8) == "the icon")
        #expect(try DockyardFolder.load(from: repo).screenshotURLs.count == 1)
    }

    @Test func screenshotsAreNamedWithTheNextFreeIndex() throws {
        let repo = try makeRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        let source = repo.appending(path: "source.png")
        try write("png", to: source)

        let folder = try DockyardFolder.load(from: repo)
        #expect(try folder.addScreenshot(from: source).lastPathComponent == "01.png")
        #expect(try folder.addScreenshot(from: source).lastPathComponent == "02.png")

        try folder.removeScreenshot(at: folder.screenshotsDirectoryURL.appending(path: "01.png"))
        // 01 is free again, so the next one fills the gap rather than jumping to 03.
        #expect(try folder.addScreenshot(from: source).lastPathComponent == "01.png")
    }
}
