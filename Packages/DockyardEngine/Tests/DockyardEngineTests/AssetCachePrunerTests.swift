import Foundation
import Testing
@testable import DockyardEngine

struct AssetCachePrunerTests {

    private func makeDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appending(path: "pruner-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func write(_ bytes: Int, to url: URL) throws {
        try Data(repeating: 0x41, count: bytes).write(to: url)
    }

    @Test func removesFilesOutsideTheKeepSet() throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        try write(10, to: dir.appending(path: "keep.png"))
        try write(30, to: dir.appending(path: "orphan.png"))

        let outcome = AssetCachePruner.prune(directory: dir, keeping: ["keep.png"])

        #expect(outcome == AssetCachePruner.Outcome(removedFiles: 1, reclaimedBytes: 30))
        #expect(FileManager.default.fileExists(atPath: dir.appending(path: "keep.png").path))
        #expect(!FileManager.default.fileExists(atPath: dir.appending(path: "orphan.png").path))
    }

    @Test func missingDirectoryIsNotAnError() {
        let dir = FileManager.default.temporaryDirectory.appending(path: "never-created-\(UUID().uuidString)")
        #expect(AssetCachePruner.prune(directory: dir, keeping: []) == .none)
    }

    @Test func emptyKeepSetClearsEverything() throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        try write(5, to: dir.appending(path: "a.png"))
        try write(5, to: dir.appending(path: "b.png"))

        let outcome = AssetCachePruner.prune(directory: dir, keeping: [])

        #expect(outcome.removedFiles == 2)
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path).isEmpty)
    }

    @Test func leavesSubdirectoriesAlone() throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let nested = dir.appending(path: "nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        let outcome = AssetCachePruner.prune(directory: dir, keeping: [])

        #expect(outcome == .none)
        #expect(FileManager.default.fileExists(atPath: nested.path))
    }

    /// The whole point: a new content hash means a new URL, and the revision it
    /// replaced must not linger on disk.
    @Test func supersededRevisionIsEvictedByURLPrune() throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = IconCache(directory: dir)

        let old = URL(string: "https://example.com/.dockyard/AppIcon.png?v=aaaaaaaaaaaa")!
        let new = URL(string: "https://example.com/.dockyard/AppIcon.png?v=bbbbbbbbbbbb")!
        try write(100, to: cache.cacheFile(for: old))
        try write(120, to: cache.cacheFile(for: new))

        let outcome = cache.prune(keeping: [new])

        #expect(outcome == AssetCachePruner.Outcome(removedFiles: 1, reclaimedBytes: 100))
        #expect(FileManager.default.fileExists(atPath: cache.cacheFile(for: new).path))
        #expect(!FileManager.default.fileExists(atPath: cache.cacheFile(for: old).path))
    }

    @Test func pruningKeepsEveryLiveURL() throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = ScreenshotCache(directory: dir)

        let live = (1...3).map { URL(string: "https://example.com/shots/0\($0).png?v=abc")! }
        let dropped = URL(string: "https://example.com/shots/09.png?v=old")!
        for url in live + [dropped] {
            try write(10, to: cache.cacheFile(for: url))
        }

        let outcome = cache.prune(keeping: Set(live))

        #expect(outcome.removedFiles == 1)
        for url in live {
            #expect(FileManager.default.fileExists(atPath: cache.cacheFile(for: url).path))
        }
    }
}
