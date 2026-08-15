import Foundation
import os

struct InstalledAppsReconciler: Sendable {

    let installRoot: URL

    init(installRoot: URL = InstallDestination.userApplications) {
        self.installRoot = installRoot
    }

    /// Drops records whose `bundlePath` no longer exists on disk.
    func dropMissing(_ records: [InstalledApp]) -> [InstalledApp] {
        records.filter { FileManager.default.fileExists(atPath: $0.bundlePath.path) }
    }

    /// Rebuilds installed.json by walking the install root and intersecting bundle IDs
    /// with the provided catalog.
    func rebuildFromDisk(catalog: [CatalogEntry]) -> [InstalledApp] {
        guard FileManager.default.fileExists(atPath: installRoot.path) else { return [] }
        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: installRoot,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            Logger.tracking.warning("Could not enumerate \(installRoot.path, privacy: .public): \(String(describing: error), privacy: .public)")
            return []
        }

        // Web apps install nothing, so they must never be matched against a
        // bundle on disk and fabricated into an installation record.
        let byID = Dictionary(uniqueKeysWithValues: catalog.filter { !$0.isWebApp }.map { ($0.id, $0) })
        var apps: [InstalledApp] = []
        for appURL in contents where appURL.pathExtension == "app" {
            guard let bundleID = try? Installer.bundleIdentifier(at: appURL) else { continue }
            guard let entry = byID[bundleID], let catalogVersion = entry.version else { continue }
            let version = (try? Installer.shortVersion(at: appURL)) ?? catalogVersion
            let installedAt = (try? appURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
            apps.append(InstalledApp(
                id: bundleID,
                displayName: entry.displayName,
                version: version,
                manifestVersion: catalogVersion,
                bundlePath: appURL,
                installedAt: installedAt
            ))
        }
        return apps
    }
}
