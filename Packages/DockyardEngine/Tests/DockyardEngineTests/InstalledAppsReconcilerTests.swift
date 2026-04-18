import Foundation
import Testing
@testable import DockyardEngine

struct InstalledAppsReconcilerTests {

    @Test func dropsRecordsForMissingBundles() {
        let tempDir = FileManager.default.temporaryDirectory
            .appending(path: "dockyard-reconcile-tests/\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let existing = tempDir.appending(path: "Exists.app")
        try? FileManager.default.createDirectory(at: existing, withIntermediateDirectories: true)

        let missing = tempDir.appending(path: "Missing.app")

        let records = [
            InstalledApp(id: "a", displayName: "Exists", version: "1", bundlePath: existing, installedAt: .now),
            InstalledApp(id: "b", displayName: "Missing", version: "1", bundlePath: missing, installedAt: .now)
        ]
        let reconciler = InstalledAppsReconciler(installRoot: tempDir)
        let pruned = reconciler.dropMissing(records)
        #expect(pruned.count == 1)
        #expect(pruned.first?.id == "a")

        try? FileManager.default.removeItem(at: tempDir)
    }
}
