import Foundation
import Testing
@testable import DockyardEngine

struct InstalledAppsStoreTests {

    private func makeTempStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "dockyard-store-tests/\(UUID().uuidString)")
            .appending(path: "installed.json")
    }

    @Test func emptyWhenFileMissing() {
        let store = InstalledAppsStore(fileURL: makeTempStoreURL())
        if case .empty = store.load() {} else {
            Issue.record("Expected .empty result")
        }
    }

    @Test func roundTrip() throws {
        let fileURL = makeTempStoreURL()
        let store = InstalledAppsStore(fileURL: fileURL)
        let apps = [
            InstalledApp(
                id: "com.example.a",
                displayName: "A",
                version: "1.0.0",
                bundlePath: URL(fileURLWithPath: "/Users/test/Applications/A.app"),
                installedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        ]
        try store.save(apps)

        if case .loaded(let loaded) = store.load() {
            #expect(loaded == apps)
        } else {
            Issue.record("Expected .loaded result")
        }
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
    }

    @Test func corruptFileReportsCorrupt() throws {
        let fileURL = makeTempStoreURL()
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: fileURL)

        let store = InstalledAppsStore(fileURL: fileURL)
        if case .corrupt = store.load() {} else {
            Issue.record("Expected .corrupt result")
        }
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
    }

    @Test func quarantineMovesTheFile() throws {
        let fileURL = makeTempStoreURL()
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("garbage".utf8).write(to: fileURL)

        let store = InstalledAppsStore(fileURL: fileURL)
        let dest = try store.quarantineCorrupt()
        #expect(FileManager.default.fileExists(atPath: dest.path))
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
    }
}
