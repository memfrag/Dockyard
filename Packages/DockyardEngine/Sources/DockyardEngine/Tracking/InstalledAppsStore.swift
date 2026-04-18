import Foundation
import os

struct InstalledAppsStore: Sendable {

    enum LoadResult: Sendable {
        case loaded([InstalledApp])
        case empty
        case corrupt(originalContents: Data, decodeError: String)
    }

    let fileURL: URL

    init(fileURL: URL = InstalledAppsStore.defaultFileURL) {
        self.fileURL = fileURL
    }

    static var defaultFileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appending(path: "Dockyard/installed.json")
    }

    func load() -> LoadResult {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .empty }
        guard let data = try? Data(contentsOf: fileURL) else { return .empty }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let apps = try decoder.decode([InstalledApp].self, from: data)
            return .loaded(apps)
        } catch {
            return .corrupt(originalContents: data, decodeError: String(describing: error))
        }
    }

    func save(_ apps: [InstalledApp]) throws {
        let parent = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(apps)
        let tmp = parent.appending(path: ".installed.json.\(UUID().uuidString).tmp")
        try data.write(to: tmp, options: [.atomic])
        _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tmp)
    }

    /// Moves a corrupt installed.json aside for forensics. Returns the destination URL.
    @discardableResult
    func quarantineCorrupt() throws -> URL {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let stamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let dest = fileURL.deletingLastPathComponent()
            .appending(path: "installed.json.corrupt-\(stamp)")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.moveItem(at: fileURL, to: dest)
        }
        return dest
    }
}
