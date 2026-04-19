import DockyardEngine
import Foundation

struct ManifestBuilder {

    let api: GitHubAPIClient
    let hasher: RemoteHasher?

    init(api: GitHubAPIClient, hasher: RemoteHasher?) {
        self.api = api
        self.hasher = hasher
    }

    func build(config: AuthoringConfig) async throws -> CatalogManifest {
        var entries: [CatalogEntry] = []
        entries.reserveCapacity(config.apps.count)

        for authoring in config.apps {
            let owner = authoring.github.owner
            let repo = authoring.github.repo

            let release = try await api.latestRelease(owner: owner, repo: repo)
            let asset = try AssetSelector.select(from: release.assets, pattern: authoring.assetPattern)

            var sha256: String? = assetDigestSHA256(asset)
            if sha256 == nil, let hasher {
                sha256 = try await hasher.sha256(of: asset.browserDownloadURL)
            }

            let screenshotURLs = try await fetchScreenshotURLs(owner: owner, repo: repo)
            let aboutURL = try await api
                .getFile(owner: owner, repo: repo, path: ".dockyard/about.md")?
                .downloadURL

            let entry = CatalogEntry(
                id: authoring.id,
                displayName: authoring.displayName,
                category: authoring.category,
                summary: authoring.summary,
                iconURL: authoring.iconURL,
                version: release.versionFromTag,
                dmgURL: asset.browserDownloadURL,
                dmgSize: asset.size,
                dmgSHA256: sha256,
                github: GitHubRepo(owner: owner, repo: repo),
                channel: authoring.channel ?? .release,
                screenshotURLs: screenshotURLs,
                aboutURL: aboutURL,
                releaseNotes: release.body?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            )
            entries.append(entry)
        }

        return CatalogManifest(generatedAt: Date(), apps: entries)
    }

    private func fetchScreenshotURLs(owner: String, repo: String) async throws -> [URL] {
        let entries = try await api.listDirectory(
            owner: owner,
            repo: repo,
            path: ".dockyard/screenshots"
        )
        return entries
            .filter { $0.type == "file" && Self.isImage($0.name) }
            .compactMap { $0.downloadURL }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func assetDigestSHA256(_ asset: GitHubAsset) -> String? {
        guard let digest = asset.digest else { return nil }
        if digest.hasPrefix("sha256:") {
            return String(digest.dropFirst("sha256:".count))
        }
        return nil
    }

    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp"]

    private static func isImage(_ filename: String) -> Bool {
        guard let ext = filename.split(separator: ".").last else { return false }
        return imageExtensions.contains(ext.lowercased())
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
