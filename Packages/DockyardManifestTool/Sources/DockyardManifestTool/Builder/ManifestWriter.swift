import DockyardEngine
import Foundation

enum ManifestWriter {

    /// Writes `manifest` to `url`. Returns `true` if the file was written, `false` if the content
    /// (ignoring `generatedAt`) matched the existing file and the write was skipped.
    @discardableResult
    static func write(_ manifest: CatalogManifest, to url: URL) throws -> Bool {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let newData = try encoder.encode(manifest)
        let newContentHash = try contentHash(of: manifest, using: encoder)

        if FileManager.default.fileExists(atPath: url.path),
           let existingData = try? Data(contentsOf: url),
           let existingManifest = try? decode(existingData) {
            let existingHash = try contentHash(of: existingManifest, using: encoder)
            if existingHash == newContentHash {
                return false
            }
        }

        let parent = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let tmp = parent.appending(path: ".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        try newData.write(to: tmp, options: [.atomic])
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
        } else {
            try FileManager.default.moveItem(at: tmp, to: url)
        }
        return true
    }

    private static func decode(_ data: Data) throws -> CatalogManifest {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CatalogManifest.self, from: data)
    }

    private static func contentHash(of manifest: CatalogManifest, using encoder: JSONEncoder) throws -> Data {
        // Strip generatedAt by rebuilding with a fixed sentinel, then encode.
        let stripped = CatalogManifest(
            schemaVersion: manifest.schemaVersion,
            generatedAt: Date(timeIntervalSince1970: 0),
            apps: manifest.apps
        )
        return try encoder.encode(stripped)
    }
}
