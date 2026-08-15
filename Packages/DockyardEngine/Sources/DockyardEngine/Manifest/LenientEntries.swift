import Foundation
import os

/// Decodes an array of `CatalogEntry` element by element, dropping the ones that
/// fail instead of failing the whole array.
///
/// A plain `[CatalogEntry]` is all-or-nothing: one entry missing a required field
/// throws, and the app is left with an empty catalog and a stale banner. That is
/// the exact failure a manifest-side mistake or a future schema addition would
/// cause, so the cost of a bad entry is capped at that one card instead.
struct LenientEntries: Decodable {

    let entries: [CatalogEntry]
    /// How many elements were dropped — surfaced in logs, and asserted in tests.
    let skippedCount: Int

    init(from decoder: Decoder) throws {
        // Decoding element-wise through a wrapper that never throws keeps the
        // container advancing exactly one element per iteration. Catching the
        // error from `container.decode(CatalogEntry.self)` directly would not:
        // whether a failed decode consumes its element is an implementation
        // detail, so a manual skip risks eating the following valid entry.
        let wrapped = try [FailableEntry](from: decoder)
        let decoded = wrapped.compactMap(\.entry)
        let skipped = wrapped.count - decoded.count
        entries = decoded
        skippedCount = skipped

        if skipped > 0 {
            Logger.catalog.warning("Skipped \(skipped, privacy: .public) undecodable catalog entr(ies)")
            for failure in wrapped.compactMap(\.failure) {
                Logger.catalog.warning("Undecodable catalog entry: \(String(describing: failure), privacy: .public)")
            }
        }
    }

    private struct FailableEntry: Decodable {
        let entry: CatalogEntry?
        let failure: Error?

        init(from decoder: Decoder) throws {
            do {
                entry = try CatalogEntry(from: decoder)
                failure = nil
            } catch {
                entry = nil
                failure = error
            }
        }
    }
}
