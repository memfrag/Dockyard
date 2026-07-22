import DockyardEngine
import Foundation

struct ManifestBuilder {

    let api: GitHubAPIClient
    let hasher: RemoteHasher?
    let previous: PreviousManifest
    let forceHash: Bool

    init(
        api: GitHubAPIClient,
        hasher: RemoteHasher?,
        previous: PreviousManifest = PreviousManifest(),
        forceHash: Bool = false
    ) {
        self.api = api
        self.hasher = hasher
        self.previous = previous
        self.forceHash = forceHash
    }

    func build(config: AuthoringConfig) async throws -> CatalogManifest {
        var entries: [CatalogEntry] = []
        entries.reserveCapacity(config.apps.count)

        for authoring in config.apps {
            let owner = authoring.github.owner
            let repo = authoring.github.repo

            let repoMetadata = try await fetchRepoMetadata(owner: owner, repo: repo)
            let repoIconURL: URL? = if authoring.iconURL == nil {
                try await api.getFile(owner: owner, repo: repo, path: ".dockyard/AppIcon.png")?.downloadURL
            } else {
                nil
            }
            let metadata = try ResolvedAppMetadata.merge(
                config: authoring,
                repo: repoMetadata,
                repoIconURL: repoIconURL
            )

            let release = try await api.latestRelease(owner: owner, repo: repo)
            let asset = try AssetSelector.select(from: release.assets, pattern: metadata.assetPattern)

            let sha256 = try await resolveSHA256(id: metadata.id, asset: asset, displayName: metadata.displayName)

            let screenshotURLs = try await fetchScreenshotURLs(owner: owner, repo: repo)
            let aboutURL = try await api
                .getFile(owner: owner, repo: repo, path: ".dockyard/about.md")?
                .downloadURL
            let developer = try await fetchDeveloperName(owner: owner)
            let requiredVersion = try await fetchRequiredVersion(owner: owner, repo: repo)

            let entry = CatalogEntry(
                id: metadata.id,
                displayName: metadata.displayName,
                category: metadata.category,
                summary: metadata.summary,
                iconURL: metadata.iconURL,
                version: release.versionFromTag,
                dmgURL: asset.browserDownloadURL,
                dmgSize: asset.size,
                dmgSHA256: sha256,
                github: GitHubRepo(owner: owner, repo: repo),
                channel: metadata.channel,
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

    /// Three-tier hash resolution: GitHub's asset digest (free), then the hash
    /// cached in the previous manifest (matched on URL + size), then — only
    /// for a genuinely new release — downloading the DMG to hash it.
    private func resolveSHA256(id: String, asset: GitHubAsset, displayName: String) async throws -> String? {
        if let digest = assetDigestSHA256(asset) {
            logHash(displayName, tier: "digest")
            return digest
        }
        if !forceHash,
           let cached = previous.cachedSHA256(id: id, dmgURL: asset.browserDownloadURL, dmgSize: asset.size) {
            logHash(displayName, tier: "cached")
            return cached
        }
        if let hasher {
            let hash = try await hasher.sha256(of: asset.browserDownloadURL)
            logHash(displayName, tier: "downloaded")
            return hash
        }
        logHash(displayName, tier: "none")
        return nil
    }

    private func logHash(_ name: String, tier: String) {
        FileHandle.standardError.write(Data("\(name): hash: \(tier)\n".utf8))
    }

    /// Fetches the app repo's own `.dockyard/dockyard.json`. A missing file is
    /// fine (nil); an unreachable or malformed one is a hard error so a broken
    /// metadata file can't silently drop an app from the catalog.
    private func fetchRepoMetadata(owner: String, repo: String) async throws -> RepoMetadata? {
        guard let file = try await api.getFile(owner: owner, repo: repo, path: ".dockyard/dockyard.json"),
              let downloadURL = file.downloadURL else {
            return nil
        }
        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(from: downloadURL)
        } catch {
            throw RepoMetadataError.malformed(owner: owner, repo: repo, underlying: "download failed: \(error)")
        }
        return try RepoMetadata.decode(data, owner: owner, repo: repo)
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
