import Foundation
import os

/// Sweeps cached asset files the catalog no longer references.
///
/// The icon, screenshot and about caches key on the asset URL and never
/// revalidate, and the manifest stamps those URLs with the file's content hash —
/// so every upstream edit leaves the previous revision behind as an orphan, as
/// does every app dropped from the catalog. Sweeping against the live catalog
/// keeps the caches proportional to what the catalog holds rather than to its
/// entire history.
public enum AssetCachePruner {

    public struct Outcome: Sendable, Equatable {
        public let removedFiles: Int
        public let reclaimedBytes: Int64

        public static let none = Outcome(removedFiles: 0, reclaimedBytes: 0)

        public static func + (lhs: Outcome, rhs: Outcome) -> Outcome {
            Outcome(
                removedFiles: lhs.removedFiles + rhs.removedFiles,
                reclaimedBytes: lhs.reclaimedBytes + rhs.reclaimedBytes
            )
        }
    }

    /// Deletes every file directly inside `directory` whose name isn't in `keeping`.
    /// A missing directory is not an error — nothing has been cached yet.
    static func prune(directory: URL, keeping: Set<String>) -> Outcome {
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
        ) else {
            return .none
        }

        var outcome = Outcome.none
        for entry in entries where !keeping.contains(entry.lastPathComponent) {
            let values = try? entry.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            let size = Int64(values?.fileSize ?? 0)
            do {
                try fileManager.removeItem(at: entry)
                outcome = outcome + Outcome(removedFiles: 1, reclaimedBytes: size)
            } catch {
                Logger.catalog.warning(
                    "Could not evict cached asset \(entry.lastPathComponent, privacy: .public): \(String(describing: error), privacy: .public)"
                )
            }
        }
        return outcome
    }
}
