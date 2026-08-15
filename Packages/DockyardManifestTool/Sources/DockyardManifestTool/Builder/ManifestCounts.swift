import DockyardEngine
import Foundation

/// Describes what a manifest holds, mentioning web apps only when there are any
/// so output for a native-only catalog reads exactly as it always has.
enum ManifestCounts {

    static func describe(_ manifest: CatalogManifest) -> String {
        let apps = "\(manifest.apps.count) app\(manifest.apps.count == 1 ? "" : "s")"
        guard !manifest.webApps.isEmpty else { return apps }
        return "\(apps), \(manifest.webApps.count) web app\(manifest.webApps.count == 1 ? "" : "s")"
    }
}
