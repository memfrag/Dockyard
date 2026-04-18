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
            let release = try await api.latestRelease(
                owner: authoring.github.owner,
                repo: authoring.github.repo
            )
            let asset = try AssetSelector.select(from: release.assets, pattern: authoring.assetPattern)

            var sha256: String? = assetDigestSHA256(asset)
            if sha256 == nil, let hasher {
                sha256 = try await hasher.sha256(of: asset.browserDownloadURL)
            }

            let entry = CatalogEntry(
                id: authoring.id,
                displayName: authoring.displayName,
                category: authoring.category,
                summary: authoring.summary,
                iconURL: authoring.iconURL,
                version: release.versionFromTag,
                dmgURL: asset.browserDownloadURL,
                dmgSize: asset.size,
                dmgSHA256: sha256
            )
            entries.append(entry)
        }

        return CatalogManifest(generatedAt: Date(), apps: entries)
    }

    private func assetDigestSHA256(_ asset: GitHubAsset) -> String? {
        guard let digest = asset.digest else { return nil }
        if digest.hasPrefix("sha256:") {
            return String(digest.dropFirst("sha256:".count))
        }
        return nil
    }
}
