import Foundation
import Testing
@testable import DockyardManifestTool

@Suite struct AssetURLVersioningTests {

    private let raw = URL(string: "https://raw.githubusercontent.com/acme/widget/main/.dockyard/AppIcon.png")!

    @Test func appendsShortBlobHash() {
        let versioned = AssetURLVersioning.versioned(raw, sha: "0123456789abcdef0123456789abcdef01234567")
        #expect(versioned.absoluteString == raw.absoluteString + "?v=0123456789ab")
    }

    @Test func differentContentYieldsDifferentURL() {
        let a = AssetURLVersioning.versioned(raw, sha: "aaaaaaaaaaaaaaaaaaaa")
        let b = AssetURLVersioning.versioned(raw, sha: "bbbbbbbbbbbbbbbbbbbb")
        #expect(a != b)
    }

    @Test func sameContentIsStableAcrossBuilds() {
        let sha = "0123456789abcdef0123456789abcdef01234567"
        #expect(AssetURLVersioning.versioned(raw, sha: sha) == AssetURLVersioning.versioned(raw, sha: sha))
    }

    @Test func missingHashLeavesURLUntouched() {
        #expect(AssetURLVersioning.versioned(raw, sha: nil) == raw)
        #expect(AssetURLVersioning.versioned(raw, sha: "") == raw)
    }

    @Test func preservesExistingQueryItems() {
        let tokenized = URL(string: "https://raw.githubusercontent.com/acme/widget/main/a.png?token=abc")!
        let versioned = AssetURLVersioning.versioned(tokenized, sha: "0123456789abcdef")
        let items = URLComponents(url: versioned, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.count == 2)
        #expect(items.first(where: { $0.name == "token" })?.value == "abc")
        #expect(items.first(where: { $0.name == "v" })?.value == "0123456789ab")
    }

    /// The caches key on the whole URL but derive the file extension from the path,
    /// so the query must not disturb it.
    @Test func versionedURLKeepsItsPathExtension() {
        let versioned = AssetURLVersioning.versioned(raw, sha: "0123456789abcdef")
        #expect(versioned.pathExtension == "png")
        #expect(versioned.lastPathComponent == "AppIcon.png")
    }

    @Test func entryWithoutDownloadURLYieldsNil() {
        let dir = GitHubContentsEntry(
            name: "screenshots",
            path: ".dockyard/screenshots",
            type: "dir",
            downloadURL: nil,
            size: 0,
            sha: "0123456789abcdef"
        )
        #expect(AssetURLVersioning.versionedDownloadURL(of: dir) == nil)
        #expect(AssetURLVersioning.versionedDownloadURL(of: nil) == nil)
    }
}
