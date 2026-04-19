import Foundation

struct EditorialLoader: Sendable {

    let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func load(from url: URL) async throws -> Editorial {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        let data: Data
        do {
            let (body, response) = try await urlSession.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw EngineError.editorialUnreachable(underlying: "HTTP \(http.statusCode)")
            }
            data = body
        } catch let error as EngineError {
            throw error
        } catch {
            throw EngineError.editorialUnreachable(underlying: String(describing: error))
        }

        return try Self.decode(data)
    }

    static func decode(_ data: Data) throws -> Editorial {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let editorial: Editorial
        do {
            editorial = try decoder.decode(Editorial.self, from: data)
        } catch {
            throw EngineError.editorialDecodeFailed(underlying: String(describing: error))
        }

        guard editorial.schemaVersion == Editorial.currentSchemaVersion else {
            throw EngineError.unsupportedEditorialSchemaVersion(
                found: editorial.schemaVersion,
                expected: Editorial.currentSchemaVersion
            )
        }
        return editorial
    }
}
