import DockyardEngine
import Foundation

/// The previously generated manifest, used as a hash cache so unchanged
/// releases never require re-downloading their DMGs.
struct PreviousManifest {

    let entriesByID: [CatalogEntry.ID: CatalogEntry]

    init(entries: [CatalogEntry] = []) {
        entriesByID = Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Best-effort load; a missing or corrupt file yields an empty cache.
    static func load(from url: URL) -> PreviousManifest {
        guard let data = try? Data(contentsOf: url) else { return PreviousManifest() }
        return load(from: data)
    }

    /// Best-effort decode; corrupt data yields an empty cache.
    static func load(from data: Data) -> PreviousManifest {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let manifest = try? decoder.decode(CatalogManifest.self, from: data) else {
            return PreviousManifest()
        }
        return PreviousManifest(entries: manifest.apps)
    }

    /// Returns the cached hash only when both URL and size still match the
    /// resolved asset — a re-uploaded asset keeps the same URL, so size acts
    /// as a cheap staleness signal.
    func cachedSHA256(id: CatalogEntry.ID, dmgURL: URL, dmgSize: Int64) -> String? {
        guard let entry = entriesByID[id],
              entry.dmgURL == dmgURL,
              entry.dmgSize == dmgSize else {
            return nil
        }
        return entry.dmgSHA256
    }
}
