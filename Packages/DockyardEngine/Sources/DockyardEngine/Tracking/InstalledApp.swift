import Foundation

public struct InstalledApp: Codable, Equatable, Identifiable, Sendable {

    public let id: CatalogEntry.ID
    public let displayName: String
    /// The `CFBundleShortVersionString` read from the bundle on disk after install.
    public let version: String
    /// The catalog `version` at the time of the install. When this differs from
    /// `version`, the upstream DMG was packaged with a stale `Info.plist` and the
    /// card surfaces a mismatch warning. `nil` for records written by older builds.
    public let manifestVersion: String?
    public let bundlePath: URL
    public let installedAt: Date

    public init(
        id: CatalogEntry.ID,
        displayName: String,
        version: String,
        manifestVersion: String? = nil,
        bundlePath: URL,
        installedAt: Date
    ) {
        self.id = id
        self.displayName = displayName
        self.version = version
        self.manifestVersion = manifestVersion
        self.bundlePath = bundlePath
        self.installedAt = installedAt
    }

    /// True when we know what catalog version was installed and the on-disk plist
    /// version disagrees with it. Returns `false` for records without a recorded
    /// `manifestVersion` (legacy installs, where intent is unknown).
    public var hasVersionMismatch: Bool {
        guard let manifestVersion else { return false }
        return manifestVersion != version
    }
}
