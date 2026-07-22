import DockyardEngine
import Foundation

enum MetadataError: Error, CustomStringConvertible {
    case missingFields(owner: String, repo: String, fields: [String])

    var description: String {
        switch self {
        case .missingFields(let owner, let repo, let fields):
            return """
            \(owner)/\(repo) is missing required metadata: \(fields.joined(separator: ", ")). \
            Add .dockyard/dockyard.json to the app repo or fill in the config entry.
            """
        }
    }
}

/// The per-app metadata after merging the authoring config with the app
/// repo's own `.dockyard/dockyard.json`. Config values win.
struct ResolvedAppMetadata {

    let id: String
    let displayName: String
    let category: String
    let summary: String
    let iconURL: URL
    let assetPattern: String?
    let channel: ReleaseChannel

    static func merge(
        config: AuthoringEntry,
        repo: RepoMetadata?,
        repoIconURL: URL?
    ) throws -> ResolvedAppMetadata {
        let id = value(config.id) ?? value(repo?.id)
        let displayName = value(config.displayName) ?? value(repo?.displayName)
        let category = value(config.category) ?? value(repo?.category)
        let summary = value(config.summary) ?? value(repo?.summary)
        let iconURL = config.iconURL ?? repoIconURL

        var missing: [String] = []
        if id == nil { missing.append("id") }
        if displayName == nil { missing.append("displayName") }
        if category == nil { missing.append("category") }
        if summary == nil { missing.append("summary") }
        if iconURL == nil { missing.append("iconURL (.dockyard/AppIcon.png)") }
        guard let id, let displayName, let category, let summary, let iconURL else {
            throw MetadataError.missingFields(
                owner: config.github.owner,
                repo: config.github.repo,
                fields: missing
            )
        }

        return ResolvedAppMetadata(
            id: id,
            displayName: displayName,
            category: category,
            summary: summary,
            iconURL: iconURL,
            assetPattern: config.assetPattern ?? repo?.assetPattern,
            channel: config.channel ?? repo?.channel ?? .release
        )
    }

    /// Treats empty strings and literal "TODO" scaffold placeholders as absent
    /// so a half-filled scaffold fails the build instead of shipping "TODO".
    private static func value(_ string: String?) -> String? {
        guard let string else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "TODO" { return nil }
        return trimmed
    }
}
