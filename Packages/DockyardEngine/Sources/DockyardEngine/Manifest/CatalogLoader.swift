import Foundation

struct CatalogLoader: Sendable {

    let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func load(from url: URL) async throws -> CatalogManifest {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        let data: Data
        do {
            let (body, response) = try await urlSession.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw EngineError.manifestUnreachable(underlying: "HTTP \(http.statusCode)")
            }
            data = body
        } catch let error as EngineError {
            throw error
        } catch {
            throw EngineError.manifestUnreachable(underlying: String(describing: error))
        }

        return try Self.decode(data)
    }

    static func decode(_ data: Data) throws -> CatalogManifest {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest: CatalogManifest
        do {
            manifest = try decoder.decode(CatalogManifest.self, from: data)
        } catch {
            throw EngineError.manifestDecodeFailed(underlying: String(describing: error))
        }

        guard manifest.schemaVersion == CatalogManifest.currentSchemaVersion else {
            throw EngineError.unsupportedSchemaVersion(
                found: manifest.schemaVersion,
                expected: CatalogManifest.currentSchemaVersion
            )
        }
        return manifest
    }
}
