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
            let developer = try await fetchDeveloperName(owner: owner)
            let requiredVersion = try await fetchRequiredVersion(owner: owner, repo: repo)

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
                releaseNotes: release.body?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
                developer: developer,
                requiredVersion: requiredVersion
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

    /// Uses the GitHub owner's display `name` (falls back to the login handle if not
    /// set). One API call per app.
    private func fetchDeveloperName(owner: String) async throws -> String? {
        let profile = try await api.ownerProfile(login: owner)
        if let name = profile?.name?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
            return name
        }
        return owner.nonEmpty
    }

    /// Extracts `MACOSX_DEPLOYMENT_TARGET` from the first `.xcodeproj/project.pbxproj`
    /// found at the repo root. Returns nil on any failure (no xcodeproj, file unreachable,
    /// regex miss) — enrichment is best-effort.
    private func fetchRequiredVersion(owner: String, repo: String) async throws -> String? {
        let rootEntries = try await api.listDirectory(owner: owner, repo: repo, path: "")
        guard let xcodeProj = rootEntries.first(where: {
            $0.type == "dir" && $0.name.hasSuffix(".xcodeproj")
        }) else {
            return nil
        }
        let pbxprojPath = "\(xcodeProj.name)/project.pbxproj"
        guard let file = try await api.getFile(owner: owner, repo: repo, path: pbxprojPath),
              let downloadURL = file.downloadURL else {
            return nil
        }
        guard let (data, _) = try? await URLSession.shared.data(from: downloadURL),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        return Self.extractDeploymentTarget(from: text)
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

    /// Pulls the first `MACOSX_DEPLOYMENT_TARGET = X.Y;` value from the pbxproj
    /// text. In multi-configuration projects the value is almost always the same
    /// across Debug/Release build configs, so "first match" is good enough.
    static func extractDeploymentTarget(from pbxproj: String) -> String? {
        let regex = /MACOSX_DEPLOYMENT_TARGET = ([0-9]+(?:\.[0-9]+)?);/
        guard let match = pbxproj.firstMatch(of: regex) else {
            return nil
        }
        return String(match.output.1).nonEmpty
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
