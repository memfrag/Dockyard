import DockyardEngine
import Foundation
import Testing
@testable import DockyardManifestTool

@Suite struct WebAppConfigTests {

    private let configJSON = """
    {
      "apps": [
        { "github": { "owner": "acme", "repo": "widget" } }
      ],
      "webApps": [
        {
          "id": "web.example.app",
          "displayName": "Some Web App",
          "category": "Productivity",
          "summary": "Runs in your browser.",
          "iconURL": "https://example.com/icon.png",
          "webURL": "https://example.com/app"
        }
      ]
    }
    """

    @Test func decodesWebApps() throws {
        let config = try JSONDecoder().decode(AuthoringConfig.self, from: Data(configJSON.utf8))
        #expect(config.apps.count == 1)
        #expect(config.webApps.count == 1)
        #expect(config.webApps.first?.webURL == URL(string: "https://example.com/app"))
    }

    /// Every existing config predates `webApps` and must keep loading.
    @Test func configWithoutWebAppsDecodes() throws {
        let json = #"{ "apps": [ { "github": { "owner": "acme", "repo": "widget" } } ] }"#
        let config = try JSONDecoder().decode(AuthoringConfig.self, from: Data(json.utf8))
        #expect(config.webApps.isEmpty)
    }

    /// `add` rewrites the whole config from decoded state, so anything it drops
    /// is deleted on disk. This is the guard against that.
    @Test func reEncodingPreservesWebApps() throws {
        let config = try JSONDecoder().decode(AuthoringConfig.self, from: Data(configJSON.utf8))
        let extended = AuthoringConfig(
            apps: config.apps + [AuthoringEntry(github: .init(owner: "acme", repo: "other"), assetPattern: nil)],
            webApps: config.webApps
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let round = try JSONDecoder().decode(AuthoringConfig.self, from: try encoder.encode(extended))

        #expect(round.apps.count == 2)
        #expect(round.webApps.count == 1, "web apps must survive a config rewrite")
        #expect(round.webApps.first?.id == "web.example.app")
    }

    /// Configs with no web apps shouldn't gain the key.
    @Test func encodingOmitsEmptyWebApps() throws {
        let config = AuthoringConfig(
            apps: [AuthoringEntry(github: .init(owner: "acme", repo: "widget"), assetPattern: nil)],
            webApps: []
        )
        let json = String(decoding: try JSONEncoder().encode(config), as: UTF8.self)
        #expect(!json.contains("webApps"))
    }

    // MARK: - Resolution

    private func makeWebApp(
        id: String = "web.example.app",
        summary: String = "Runs in your browser.",
        webURL: String = "https://example.com/app"
    ) -> AuthoringWebApp {
        AuthoringWebApp(
            id: id,
            displayName: "Some Web App",
            category: "Productivity",
            summary: summary,
            iconURL: URL(string: "https://example.com/icon.png")!,
            webURL: URL(string: webURL)!,
            channel: nil,
            developer: "Example AB",
            aboutURL: nil,
            screenshotURLs: nil
        )
    }

    @Test func resolvesToACatalogEntryWithNoDMGFields() throws {
        let entry = try makeWebApp().resolved()
        #expect(entry.isWebApp)
        #expect(entry.webURL == URL(string: "https://example.com/app"))
        #expect(entry.version == nil)
        #expect(entry.dmgURL == nil)
        #expect(entry.dmgSize == nil)
        #expect(entry.dmgSHA256 == nil)
        #expect(entry.github == nil)
        #expect(entry.channel == .release)
        #expect(entry.developer == "Example AB")
    }

    @Test func placeholderSummaryIsRejected() {
        #expect(throws: WebAppConfigError.self) {
            try makeWebApp(summary: "TODO").resolved()
        }
        #expect(throws: WebAppConfigError.self) {
            try makeWebApp(summary: "  ").resolved()
        }
    }

    /// NSWorkspace would silently do nothing with a non-web scheme.
    @Test func nonWebSchemeIsRejected() {
        #expect(throws: WebAppConfigError.self) {
            try makeWebApp(webURL: "file:///Applications").resolved()
        }
        #expect(throws: WebAppConfigError.self) {
            try makeWebApp(webURL: "mailto:hi@example.com").resolved()
        }
    }

    // MARK: - Id uniqueness

    private func native(id: String) -> CatalogEntry {
        CatalogEntry(
            id: id,
            displayName: "Widget",
            category: "Productivity",
            summary: "A widget.",
            iconURL: URL(string: "https://example.com/w.png")!,
            version: "1.0.0",
            dmgURL: URL(string: "https://example.com/w.dmg")!,
            dmgSize: 1
        )
    }

    @Test func idCollisionBetweenNativeAndWebAppFails() throws {
        let web = try makeWebApp(id: "com.acme.widget").resolved()
        #expect(throws: WebAppConfigError.self) {
            try ManifestBuilder.assertUniqueIDs(apps: [native(id: "com.acme.widget")], webApps: [web])
        }
    }

    @Test func distinctIDsPass() throws {
        let web = try makeWebApp().resolved()
        try ManifestBuilder.assertUniqueIDs(apps: [native(id: "com.acme.widget")], webApps: [web])
    }
}

@Suite struct WebAppManifestWritingTests {

    private func manifest(webAppSummary: String) throws -> CatalogManifest {
        let web = try AuthoringWebApp(
            id: "web.example.app",
            displayName: "Some Web App",
            category: "Productivity",
            summary: webAppSummary,
            iconURL: URL(string: "https://example.com/icon.png")!,
            webURL: URL(string: "https://example.com/app")!,
            channel: nil,
            developer: nil,
            aboutURL: nil,
            screenshotURLs: nil
        ).resolved()

        return CatalogManifest(
            generatedAt: Date(timeIntervalSince1970: 1_000),
            apps: [],
            webApps: [web]
        )
    }

    /// The idempotency check hashes the manifest with `generatedAt` stripped.
    /// If it dropped `webApps`, a web-app-only edit would hash identically and
    /// the tool would report "no changes" and never write the file.
    @Test func webAppOnlyChangeIsWritten() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "manifest.json")

        #expect(try ManifestWriter.write(manifest(webAppSummary: "Runs in your browser."), to: url))
        // Same content again: skipped.
        #expect(try ManifestWriter.write(manifest(webAppSummary: "Runs in your browser."), to: url) == false)
        // Only the web app's summary changed: must still be written.
        #expect(try ManifestWriter.write(manifest(webAppSummary: "Now with more browser."), to: url))
    }
}

@Suite struct WebAppDiffTests {

    private func web(summary: String) throws -> CatalogEntry {
        try AuthoringWebApp(
            id: "web.example.app",
            displayName: "Some Web App",
            category: "Productivity",
            summary: summary,
            iconURL: URL(string: "https://example.com/icon.png")!,
            webURL: URL(string: "https://example.com/app")!,
            channel: nil,
            developer: nil,
            aboutURL: nil,
            screenshotURLs: nil
        ).resolved()
    }

    @Test func newWebAppShowsAsAdded() throws {
        let new = CatalogManifest(generatedAt: Date(), apps: [], webApps: [try web(summary: "One.")])
        let diff = ManifestDiff.between(previous: PreviousManifest(), new: new)
        #expect(diff.added == ["Some Web App"])
        #expect(diff.versionChanges.isEmpty)
    }

    /// A web app has no version, so a change can only ever be metadata —
    /// it must never be reported as a version change.
    @Test func changedWebAppIsMetadataOnly() throws {
        let previous = PreviousManifest(entries: [try web(summary: "One.")])
        let new = CatalogManifest(generatedAt: Date(), apps: [], webApps: [try web(summary: "Two.")])
        let diff = ManifestDiff.between(previous: previous, new: new)
        #expect(diff.metadataOnlyChanges == ["Some Web App"])
        #expect(diff.versionChanges.isEmpty)
        #expect(diff.added.isEmpty)
    }

    @Test func removedWebAppIsReported() throws {
        let previous = PreviousManifest(entries: [try web(summary: "One.")])
        let new = CatalogManifest(generatedAt: Date(), apps: [], webApps: [])
        let diff = ManifestDiff.between(previous: previous, new: new)
        #expect(diff.removed == ["Some Web App"])
    }

    /// The hash cache indexes web apps too, but they can never satisfy a lookup.
    @Test func webAppNeverProvidesACachedHash() throws {
        let previous = PreviousManifest(entries: [try web(summary: "One.")])
        let hash = previous.cachedSHA256(
            id: "web.example.app",
            dmgURL: URL(string: "https://example.com/x.dmg")!,
            dmgSize: 1
        )
        #expect(hash == nil)
    }
}
