import DockyardEngine
import Foundation
import Testing
@testable import DockyardManifestTool

@Suite struct MetadataMergeTests {

    private let github = AuthoringEntry.GitHub(owner: "acme", repo: "widget")

    private var fullConfig: AuthoringEntry {
        AuthoringEntry(
            github: github,
            id: "com.acme.widget",
            displayName: "Widget",
            category: "Productivity",
            summary: "From config.",
            iconURL: URL(string: "https://example.com/icon.png")!,
            assetPattern: "^Widget-.*\\.dmg$",
            channel: .beta
        )
    }

    private var repoMetadata: RepoMetadata {
        RepoMetadata(
            schemaVersion: 1,
            id: "com.acme.widget-from-repo",
            displayName: "Widget From Repo",
            category: "Development",
            summary: "From repo.",
            assetPattern: "^Repo-.*\\.dmg$",
            channel: .release
        )
    }

    @Test func configOverridesRepoMetadata() throws {
        let merged = try ResolvedAppMetadata.merge(
            config: fullConfig,
            repo: repoMetadata,
            repoIconURL: URL(string: "https://example.com/repo-icon.png")
        )
        #expect(merged.id == "com.acme.widget")
        #expect(merged.displayName == "Widget")
        #expect(merged.category == "Productivity")
        #expect(merged.summary == "From config.")
        #expect(merged.iconURL == URL(string: "https://example.com/icon.png"))
        #expect(merged.assetPattern == "^Widget-.*\\.dmg$")
        #expect(merged.channel == .beta)
    }

    @Test func repoMetadataFillsMinimalConfig() throws {
        let minimal = AuthoringEntry(github: github)
        let merged = try ResolvedAppMetadata.merge(
            config: minimal,
            repo: repoMetadata,
            repoIconURL: URL(string: "https://example.com/repo-icon.png")
        )
        #expect(merged.id == "com.acme.widget-from-repo")
        #expect(merged.displayName == "Widget From Repo")
        #expect(merged.category == "Development")
        #expect(merged.iconURL == URL(string: "https://example.com/repo-icon.png"))
        #expect(merged.assetPattern == "^Repo-.*\\.dmg$")
        #expect(merged.channel == .release)
    }

    @Test func channelDefaultsToRelease() throws {
        let minimal = AuthoringEntry(github: github)
        let repo = RepoMetadata(
            schemaVersion: 1,
            id: "com.acme.widget",
            displayName: "Widget",
            category: "Productivity",
            summary: "Summary.",
            assetPattern: nil,
            channel: nil
        )
        let merged = try ResolvedAppMetadata.merge(
            config: minimal,
            repo: repo,
            repoIconURL: URL(string: "https://example.com/repo-icon.png")
        )
        #expect(merged.channel == .release)
    }

    @Test func missingFieldsAreAllListed() {
        let minimal = AuthoringEntry(github: github)
        #expect {
            try ResolvedAppMetadata.merge(config: minimal, repo: nil, repoIconURL: nil)
        } throws: { error in
            guard case MetadataError.missingFields(let owner, let repo, let fields) = error else {
                return false
            }
            return owner == "acme" && repo == "widget"
                && fields.contains("id")
                && fields.contains("displayName")
                && fields.contains("category")
                && fields.contains("summary")
                && fields.contains(where: { $0.hasPrefix("iconURL") })
        }
    }

    @Test func todoPlaceholdersAreRejected() {
        let minimal = AuthoringEntry(github: github)
        let scaffolded = RepoMetadata(
            schemaVersion: 1,
            id: "com.acme.widget",
            displayName: "Widget",
            category: "TODO",
            summary: "TODO",
            assetPattern: nil,
            channel: nil
        )
        #expect {
            try ResolvedAppMetadata.merge(
                config: minimal,
                repo: scaffolded,
                repoIconURL: URL(string: "https://example.com/repo-icon.png")
            )
        } throws: { error in
            guard case MetadataError.missingFields(_, _, let fields) = error else {
                return false
            }
            return fields == ["category", "summary"]
        }
    }
}
