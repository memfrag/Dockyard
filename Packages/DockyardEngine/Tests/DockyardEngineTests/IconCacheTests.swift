import Foundation
import Testing
@testable import DockyardEngine

struct IconCacheTests {

    @Test func cacheKeyIsStable() {
        let url = URL(string: "https://example.com/icons/a.png")!
        let first = IconCache.cacheKey(for: url)
        let second = IconCache.cacheKey(for: url)
        #expect(first == second)
        #expect(first.count == 64)
    }

    @Test func cacheKeyDiffersByURL() {
        let a = URL(string: "https://example.com/icons/a.png")!
        let b = URL(string: "https://example.com/icons/b.png")!
        #expect(IconCache.cacheKey(for: a) != IconCache.cacheKey(for: b))
    }

    @Test func cacheFilePreservesExtension() {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let cache = IconCache(directory: dir)
        let url = URL(string: "https://example.com/icons/a.png")!
        let file = cache.cacheFile(for: url)
        #expect(file.pathExtension == "png")
        #expect(file.deletingLastPathComponent().path == dir.path)
    }

    @Test func cacheFileDefaultsToPNGWhenMissingExtension() {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let cache = IconCache(directory: dir)
        let url = URL(string: "https://example.com/icons/untitled")!
        let file = cache.cacheFile(for: url)
        #expect(file.pathExtension == "png")
    }
}
