import DockyardEngine
import Foundation

/// A human-readable summary of what changed between two manifest builds,
/// used by `publish` for its change report and auto-generated commit message.
struct ManifestDiff {

    struct VersionChange {
        let displayName: String
        let old: String
        let new: String
    }

    let added: [String]
    let removed: [String]
    let versionChanges: [VersionChange]
    let metadataOnlyChanges: [String]

    var isEmpty: Bool {
        added.isEmpty && removed.isEmpty && versionChanges.isEmpty && metadataOnlyChanges.isEmpty
    }

    static func between(previous: PreviousManifest, new: CatalogManifest) -> ManifestDiff {
        var added: [String] = []
        var versionChanges: [VersionChange] = []
        var metadataOnly: [String] = []
        var seen = Set<CatalogEntry.ID>()

        // Web apps are diffed alongside native ones, but they have no version,
        // so any change to one is by definition a metadata change.
        for entry in new.allApps {
            seen.insert(entry.id)
            guard let old = previous.entriesByID[entry.id] else {
                added.append(entry.displayName)
                continue
            }
            if let oldVersion = old.version, let newVersion = entry.version, oldVersion != newVersion {
                versionChanges.append(VersionChange(displayName: entry.displayName, old: oldVersion, new: newVersion))
            } else if old != entry {
                metadataOnly.append(entry.displayName)
            }
        }

        let removed = previous.entriesByID.values
            .filter { !seen.contains($0.id) }
            .map(\.displayName)
            .sorted()

        return ManifestDiff(
            added: added,
            removed: removed,
            versionChanges: versionChanges,
            metadataOnlyChanges: metadataOnly
        )
    }

    /// e.g. "Update manifest: RepoRanger 1.8.3, add Unfold"
    var commitMessage: String {
        var parts: [String] = []
        parts.append(contentsOf: versionChanges.map { "\($0.displayName) \($0.new)" })
        parts.append(contentsOf: added.map { "add \($0)" })
        parts.append(contentsOf: removed.map { "remove \($0)" })
        if parts.isEmpty {
            parts.append(contentsOf: metadataOnlyChanges.map { "\($0) metadata" })
        }
        guard !parts.isEmpty else { return "Update manifest" }
        return "Update manifest: " + parts.joined(separator: ", ")
    }

    var summaryLines: [String] {
        var lines: [String] = []
        lines.append(contentsOf: versionChanges.map { "~ \($0.displayName) \($0.old) → \($0.new)" })
        lines.append(contentsOf: added.map { "+ \($0)" })
        lines.append(contentsOf: removed.map { "- \($0)" })
        lines.append(contentsOf: metadataOnlyChanges.map { "· \($0) (metadata)" })
        return lines
    }
}
