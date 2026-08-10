import Foundation

/// Stamps repo-hosted asset URLs with the file's git blob hash.
///
/// Icons, screenshots and about pages live at stable paths on `raw.githubusercontent.com`,
/// so editing one leaves its URL unchanged. The app's icon/screenshot/about caches key on
/// the URL and never revalidate, which means an updated asset would stay invisible forever
/// on machines that had already fetched it. Appending `?v=<blob hash>` gives changed
/// content a new URL — and therefore a new cache key — while leaving untouched files alone.
enum AssetURLVersioning {

    /// Length of the blob hash kept in the query. Plenty to distinguish revisions
    /// of one file, and short enough to keep the manifest readable.
    static let hashPrefixLength = 12

    static func versioned(_ url: URL, sha: String?) -> URL {
        guard let sha, !sha.isEmpty,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "v", value: String(sha.prefix(hashPrefixLength))))
        components.queryItems = items
        return components.url ?? url
    }

    /// Versioned download URL for a contents-API entry, or nil for anything that
    /// isn't a downloadable file.
    static func versionedDownloadURL(of entry: GitHubContentsEntry?) -> URL? {
        guard let entry, let url = entry.downloadURL else { return nil }
        return versioned(url, sha: entry.sha)
    }
}
