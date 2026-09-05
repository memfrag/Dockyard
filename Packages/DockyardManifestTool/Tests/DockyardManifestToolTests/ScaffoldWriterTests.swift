import DockyardEngine
import Foundation
import Testing
@testable import DockyardManifestTool

@Suite struct ScaffoldWriterTests {

    private func makeWriter(iconPNG: Data? = Data([0x89, 0x50, 0x4E, 0x47])) -> ScaffoldWriter {
        ScaffoldWriter(
            bundleID: "com.acme.widget",
            displayName: "Widget",
            assetName: "Widget-1.2.3.dmg",
            iconPNG: iconPNG
        )
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "scaffold-writer-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test func writesFullScaffold() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let result = try makeWriter().write(to: root, parts: .all)

        #expect(result.files == [
            ".dockyard/dockyard.json",
            ".dockyard/AppIcon.png",
            ".dockyard/about.md",
            ".dockyard/screenshots/README.md"
        ])
        for file in result.files {
            #expect(FileManager.default.fileExists(atPath: root.appending(path: file).path), "missing \(file)")
        }
    }

    @Test func scaffoldedMetadataIsValid() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        _ = try makeWriter().write(to: root, parts: .all)

        let data = try Data(contentsOf: root.appending(path: ".dockyard/dockyard.json"))
        let metadata = try RepoMetadata.decode(data, owner: "acme", repo: "widget")
        #expect(metadata.id == "com.acme.widget")
        #expect(metadata.displayName == "Widget")
        #expect(metadata.assetPattern == "^Widget-.*\\.dmg$")
    }

    @Test func writesOnlyRequestedParts() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let parts = ScaffoldWriter.Parts(metadata: false, icon: true, about: false, screenshots: false)
        let result = try makeWriter().write(to: root, parts: parts)

        #expect(result.files == [".dockyard/AppIcon.png"])
        #expect(!FileManager.default.fileExists(atPath: root.appending(path: ".dockyard/dockyard.json").path))
        #expect(!FileManager.default.fileExists(atPath: root.appending(path: ".dockyard/screenshots").path))
    }

    @Test func skipsIconWhenNoneWasExtracted() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let result = try makeWriter(iconPNG: nil).write(to: root, parts: .all)

        #expect(!result.files.contains(".dockyard/AppIcon.png"))
        #expect(result.files.contains(".dockyard/dockyard.json"))
    }

    @Test func leavesExistingFilesAlone() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let dockyard = root.appending(path: ".dockyard")
        try FileManager.default.createDirectory(at: dockyard, withIntermediateDirectories: true)
        let about = dockyard.appending(path: "about.md")
        try Data("Hand-written.".utf8).write(to: about)
        let icon = dockyard.appending(path: "AppIcon.png")
        try Data("the real icon".utf8).write(to: icon)

        let result = try makeWriter().write(to: root, parts: .all)

        #expect(result.files == [".dockyard/dockyard.json", ".dockyard/screenshots/README.md"])
        #expect(result.skipped == [".dockyard/AppIcon.png", ".dockyard/about.md"])
        #expect(try String(contentsOf: about, encoding: .utf8) == "Hand-written.")
        #expect(try String(contentsOf: icon, encoding: .utf8) == "the real icon")
    }

    @Test func overwriteReplacesExistingFiles() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let dockyard = root.appending(path: ".dockyard")
        try FileManager.default.createDirectory(at: dockyard, withIntermediateDirectories: true)
        let about = dockyard.appending(path: "about.md")
        try Data("Hand-written.".utf8).write(to: about)

        let result = try makeWriter().write(to: root, parts: .all, overwrite: true)

        #expect(result.skipped.isEmpty)
        #expect(result.files.contains(".dockyard/about.md"))
        #expect(try String(contentsOf: about, encoding: .utf8) != "Hand-written.")
    }

    @Test func skipsScreenshotsReadmeWhenTheFolderHasContent() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let screenshots = root.appending(path: ".dockyard/screenshots")
        try FileManager.default.createDirectory(at: screenshots, withIntermediateDirectories: true)
        try Data("png".utf8).write(to: screenshots.appending(path: "01.png"))

        let result = try makeWriter().write(to: root, parts: .all)

        #expect(result.skipped.contains(".dockyard/screenshots/README.md"))
        #expect(!FileManager.default.fileExists(atPath: screenshots.appending(path: "README.md").path))
    }

    @Test func emptyPartsMeansNothingToScaffold() {
        #expect(ScaffoldWriter.Parts(metadata: false, icon: false, about: false, screenshots: false).isEmpty)
        #expect(!ScaffoldWriter.Parts(metadata: false, icon: true, about: false, screenshots: false).isEmpty)
    }

    @Test func temporaryRootStartsEmptyOnRerun() throws {
        let root = try ScaffoldWriter.temporaryRoot(owner: "acme", repo: "widget-mac")
        _ = try makeWriter().write(to: root, parts: .all)
        #expect(FileManager.default.fileExists(atPath: root.appending(path: ".dockyard/about.md").path))

        let rerun = try ScaffoldWriter.temporaryRoot(owner: "acme", repo: "widget-mac")
        defer { try? FileManager.default.removeItem(at: rerun) }
        #expect(rerun == root)
        #expect(try FileManager.default.contentsOfDirectory(atPath: rerun.path).isEmpty)
    }
}

@Suite struct AppIconExtractionTests {

    /// Finder.app carries a classic `.icns`, so this exercises the sips path
    /// against a real bundle without needing a DMG.
    @Test func extractsIconFromSystemAppBundle() throws {
        let finder = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
        try #require(FileManager.default.fileExists(atPath: finder.path))

        let png = try #require(DmgInspector().iconPNG(appAt: finder))
        #expect(png.starts(with: [0x89, 0x50, 0x4E, 0x47]))
    }
}
