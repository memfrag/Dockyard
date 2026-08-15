import DockyardEngine
import Foundation

enum WebAppConfigError: Error, CustomStringConvertible {
    case missingFields(id: String, fields: [String])
    case invalidWebURL(id: String, url: String)
    case duplicateID(String)

    var description: String {
        switch self {
        case .missingFields(let id, let fields):
            return "Web app \(id) is missing required metadata: \(fields.joined(separator: ", "))."
        case .invalidWebURL(let id, let url):
            return "Web app \(id) has an unusable webURL (must be http or https): \(url)"
        case .duplicateID(let id):
            return "Duplicate catalog id: \(id). Every app and web app needs its own id."
        }
    }
}

/// A catalog entry that opens in the browser instead of installing.
///
/// Unlike `AuthoringEntry` there is no GitHub repo behind it, so everything is
/// stated here — there's no `.dockyard/dockyard.json` to fall back on.
struct AuthoringWebApp: Codable, Sendable {

    let id: String
    let displayName: String
    let category: String
    let summary: String
    let iconURL: URL
    let webURL: URL
    let channel: ReleaseChannel?
    let developer: String?
    let aboutURL: URL?
    let screenshotURLs: [URL]?

    /// Validates the entry and converts it to the catalog shape. Mirrors
    /// `ResolvedAppMetadata.merge`'s treatment of empty and `"TODO"` values so a
    /// half-filled entry fails loudly rather than shipping placeholders.
    func resolved() throws -> CatalogEntry {
        var missing: [String] = []
        if Self.value(id) == nil { missing.append("id") }
        if Self.value(displayName) == nil { missing.append("displayName") }
        if Self.value(category) == nil { missing.append("category") }
        if Self.value(summary) == nil { missing.append("summary") }
        guard missing.isEmpty else {
            throw WebAppConfigError.missingFields(id: id, fields: missing)
        }

        // NSWorkspace would silently do nothing with, say, a file:// or mailto: URL.
        guard let scheme = webURL.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw WebAppConfigError.invalidWebURL(id: id, url: webURL.absoluteString)
        }

        return CatalogEntry(
            id: id,
            displayName: displayName,
            category: category,
            summary: summary,
            iconURL: iconURL,
            webURL: webURL,
            channel: channel ?? .release,
            screenshotURLs: screenshotURLs ?? [],
            aboutURL: aboutURL,
            developer: developer
        )
    }

    private static func value(_ string: String?) -> String? {
        guard let trimmed = string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              trimmed != "TODO" else {
            return nil
        }
        return trimmed
    }
}
