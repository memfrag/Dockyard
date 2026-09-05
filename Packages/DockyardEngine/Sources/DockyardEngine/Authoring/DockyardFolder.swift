import Foundation

/// Reads and writes the `.dockyard/` folder an app repo publishes about itself.
///
/// The manifest tool consumes this folder over the GitHub API; this is the same
/// layout seen from a local checkout, so it can be created and edited before
/// anything is pushed.
///
/// ```
/// .dockyard/
///   dockyard.json
///   AppIcon.png
///   about.md
///   screenshots/01.png …
/// ```
public struct DockyardFolder: Sendable, Equatable {

    /// Screenshot files the manifest build will pick up, in the order it sorts them.
    public static let screenshotExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp"]

    /// Pixel size the catalog expects for `AppIcon.png`.
    public static let iconPixelSize = 512

    /// The repo root — the folder that contains `.dockyard`, not `.dockyard` itself.
    public let repositoryURL: URL

    public init(
        repositoryURL: URL,
        metadata: RepoMetadata? = nil,
        about: String? = nil,
        iconURL: URL? = nil,
        screenshotURLs: [URL] = []
    ) {
        self.repositoryURL = repositoryURL
        self.metadata = metadata
        self.about = about
        self.iconURL = iconURL
        self.screenshotURLs = screenshotURLs
    }

    /// Parsed `dockyard.json`, or nil when the repo doesn't publish one yet.
    public var metadata: RepoMetadata?
    /// Contents of `about.md`, or nil when absent.
    public var about: String?
    /// Present only when `AppIcon.png` exists on disk.
    public var iconURL: URL?
    /// Existing screenshots, sorted the way the manifest sorts them.
    public var screenshotURLs: [URL]

    public var dockyardDirectoryURL: URL { repositoryURL.appending(path: ".dockyard") }
    public var metadataURL: URL { dockyardDirectoryURL.appending(path: "dockyard.json") }
    public var aboutURL: URL { dockyardDirectoryURL.appending(path: "about.md") }
    public var defaultIconURL: URL { dockyardDirectoryURL.appending(path: "AppIcon.png") }
    public var screenshotsDirectoryURL: URL { dockyardDirectoryURL.appending(path: "screenshots") }

    /// True when the repo publishes nothing yet — saving will create the folder.
    public var isEmpty: Bool {
        metadata == nil && about == nil && iconURL == nil && screenshotURLs.isEmpty
    }

    // MARK: - Loading

    /// Reads whatever is already there. A missing folder is not an error: it
    /// yields an empty value that `save` will materialise.
    ///
    /// A malformed `dockyard.json` *is* an error — silently discarding it would
    /// mean overwriting hand-written metadata on the next save.
    public static func load(from repositoryURL: URL) throws -> DockyardFolder {
        var folder = DockyardFolder(
            repositoryURL: repositoryURL,
            metadata: nil,
            about: nil,
            iconURL: nil,
            screenshotURLs: []
        )

        if let data = try? Data(contentsOf: folder.metadataURL) {
            folder.metadata = try RepoMetadata.decode(
                data,
                owner: repositoryURL.lastPathComponent,
                repo: repositoryURL.lastPathComponent
            )
        }
        if let data = try? Data(contentsOf: folder.aboutURL) {
            folder.about = String(decoding: data, as: UTF8.self)
        }
        if FileManager.default.fileExists(atPath: folder.defaultIconURL.path) {
            folder.iconURL = folder.defaultIconURL
        }
        folder.screenshotURLs = Self.screenshots(in: folder.screenshotsDirectoryURL)
        return folder
    }

    public static func screenshots(in directory: URL) -> [URL] {
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        return entries
            .filter { screenshotExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    // MARK: - Saving

    /// Writes `dockyard.json` and `about.md`, creating `.dockyard/` if needed.
    ///
    /// Only the two text files are written; the icon and screenshots are managed
    /// through `installIcon` / `addScreenshot` so that saving a form can never
    /// disturb binary assets. An empty `about` removes the file rather than
    /// leaving a blank one, since the catalog omits the section when it's absent.
    public func save() throws {
        guard let metadata else {
            throw DockyardFolderError.noMetadataToSave
        }
        try FileManager.default.createDirectory(at: dockyardDirectoryURL, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        // Key order matters only for readability of the committed file; the
        // schema line first, then identity, then the descriptive fields.
        var object: [(String, Any)] = [
            ("schemaVersion", metadata.schemaVersion),
            ("id", metadata.id)
        ]
        if let value = metadata.displayName?.nonBlank { object.append(("displayName", value)) }
        if let value = metadata.category?.nonBlank { object.append(("category", value)) }
        if let value = metadata.summary?.nonBlank { object.append(("summary", value)) }
        if let value = metadata.assetPattern?.nonBlank { object.append(("assetPattern", value)) }
        if let channel = metadata.channel, channel != .release { object.append(("channel", channel.rawValue)) }

        try Data(Self.json(from: object).utf8).write(to: metadataURL, options: .atomic)

        if let about = about?.nonBlank {
            let terminated = about.hasSuffix("\n") ? about : about + "\n"
            try Data(terminated.utf8).write(to: aboutURL, options: .atomic)
        } else if FileManager.default.fileExists(atPath: aboutURL.path) {
            try FileManager.default.removeItem(at: aboutURL)
        }
    }

    /// Hand-rolled so the committed file keeps a stable, readable key order —
    /// `JSONEncoder` offers either insertion order (unstable) or sorted keys.
    static func json(from pairs: [(String, Any)]) -> String {
        let body = pairs.map { key, value -> String in
            switch value {
            case let int as Int: return "  \"\(key)\": \(int)"
            default:
                let escaped = "\(value)"
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                return "  \"\(key)\": \"\(escaped)\""
            }
        }
        return "{\n" + body.joined(separator: ",\n") + "\n}\n"
    }

    // MARK: - Assets

    /// Copies an image in as `AppIcon.png`, normalised to 512×512.
    public func installIcon(from source: URL) throws {
        try FileManager.default.createDirectory(at: dockyardDirectoryURL, withIntermediateDirectories: true)
        let png = try ImageNormalizer.pngData(from: source, size: Self.iconPixelSize)
        try png.write(to: defaultIconURL, options: .atomic)
    }

    /// Copies a screenshot in, named with the next free two-digit index so the
    /// manifest's alphabetical ordering matches the order they were added.
    @discardableResult
    public func addScreenshot(from source: URL) throws -> URL {
        try FileManager.default.createDirectory(at: screenshotsDirectoryURL, withIntermediateDirectories: true)
        let taken = Set(Self.screenshots(in: screenshotsDirectoryURL).map { $0.deletingPathExtension().lastPathComponent })
        var index = 1
        while taken.contains(String(format: "%02d", index)) { index += 1 }

        let ext = source.pathExtension.isEmpty ? "png" : source.pathExtension.lowercased()
        let destination = screenshotsDirectoryURL.appending(path: String(format: "%02d", index) + "." + ext)
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    public func removeScreenshot(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
}

public enum DockyardFolderError: Error, LocalizedError {
    case noMetadataToSave
    case unreadableImage(String)

    public var errorDescription: String? {
        switch self {
        case .noMetadataToSave:
            return "There is no metadata to save."
        case .unreadableImage(let path):
            return "Could not read an image at \(path)."
        }
    }
}

extension String {
    /// nil for empty or whitespace-only strings, so blank form fields are
    /// omitted from the JSON rather than written as "".
    var nonBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
