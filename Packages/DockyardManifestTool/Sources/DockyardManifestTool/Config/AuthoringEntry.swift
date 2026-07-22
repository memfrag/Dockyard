import Foundation
import DockyardEngine

/// One app in the authoring config. Only `github` is required — everything
/// else can come from the app repo's own `.dockyard/dockyard.json`. Values
/// given here override the repo's metadata, so the catalog curator always has
/// the last word.
struct AuthoringEntry: Codable, Sendable {

    struct GitHub: Codable, Sendable {
        let owner: String
        let repo: String
    }

    let github: GitHub
    let id: String?                // must equal CFBundleIdentifier of the built .app
    let displayName: String?
    let category: String?
    let summary: String?
    let iconURL: URL?              // defaults to the repo's .dockyard/AppIcon.png
    let assetPattern: String?      // optional regex; falls back to first *.dmg
    let channel: ReleaseChannel?   // optional; defaults to .release when omitted

    init(
        github: GitHub,
        id: String? = nil,
        displayName: String? = nil,
        category: String? = nil,
        summary: String? = nil,
        iconURL: URL? = nil,
        assetPattern: String? = nil,
        channel: ReleaseChannel? = nil
    ) {
        self.github = github
        self.id = id
        self.displayName = displayName
        self.category = category
        self.summary = summary
        self.iconURL = iconURL
        self.assetPattern = assetPattern
        self.channel = channel
    }
}
