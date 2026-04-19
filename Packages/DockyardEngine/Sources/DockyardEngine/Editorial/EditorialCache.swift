import Foundation

struct EditorialCache: Sendable {

    let fileURL: URL

    init(fileURL: URL = EditorialCache.defaultFileURL) {
        self.fileURL = fileURL
    }

    static var defaultFileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appending(path: "Dockyard/editorial.cache.json")
    }

    func load() -> Editorial? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? EditorialLoader.decode(data)
    }

    func save(_ editorial: Editorial) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(editorial)
        let parent = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let tmp = parent.appending(path: ".editorial.cache.json.\(UUID().uuidString).tmp")
        try data.write(to: tmp, options: [.atomic])
        _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tmp)
    }
}
