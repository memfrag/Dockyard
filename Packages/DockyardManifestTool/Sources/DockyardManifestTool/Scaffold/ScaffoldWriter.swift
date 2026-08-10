import Foundation

/// Lays out a ready-to-commit `.dockyard/` folder for an app repo that isn't
/// self-describing yet. The `add` command writes this to a temp directory so the
/// whole folder can be copied straight into the app repo.
struct ScaffoldWriter {

    /// Which parts of `.dockyard/` the app repo is still missing. Anything the
    /// repo already publishes is left out, so copying the scaffold over can
    /// never clobber existing metadata.
    struct Parts: Sendable {
        var metadata: Bool
        var icon: Bool
        var about: Bool
        var screenshots: Bool

        static let all = Parts(metadata: true, icon: true, about: true, screenshots: true)

        var isEmpty: Bool { !metadata && !icon && !about && !screenshots }
    }

    struct Result {
        /// The directory to copy `.dockyard` out of.
        let root: URL
        /// Paths written, relative to `root`, for reporting.
        let files: [String]
        /// Paths left alone because the destination already had them.
        let skipped: [String]
    }

    let bundleID: String
    let displayName: String
    let assetName: String
    let iconPNG: Data?

    /// Writes the requested parts into `root/.dockyard`, creating directories as
    /// needed. Files the destination already has are left untouched unless
    /// `overwrite` is set — scaffolding straight into an app repo must never
    /// clobber hand-written content.
    func write(to root: URL, parts: Parts, overwrite: Bool = false) throws -> Result {
        let dockyard = root.appending(path: ".dockyard")
        try FileManager.default.createDirectory(at: dockyard, withIntermediateDirectories: true)

        var files: [String] = []
        var skipped: [String] = []

        func put(_ data: Data, at path: String) throws {
            let url = root.appending(path: path)
            guard overwrite || !FileManager.default.fileExists(atPath: url.path) else {
                skipped.append(path)
                return
            }
            try data.write(to: url, options: .atomic)
            files.append(path)
        }

        if parts.metadata {
            let json = DockyardManifestTool.Add.scaffoldJSON(
                bundleID: bundleID,
                name: displayName,
                assetName: assetName
            )
            try put(Data((json + "\n").utf8), at: ".dockyard/dockyard.json")
        }

        if parts.icon, let iconPNG {
            try put(iconPNG, at: ".dockyard/AppIcon.png")
        }

        if parts.about {
            try put(Data(Self.aboutTemplate(displayName: displayName).utf8), at: ".dockyard/about.md")
        }

        if parts.screenshots {
            let screenshots = dockyard.appending(path: "screenshots")
            let existing = try? FileManager.default.contentsOfDirectory(atPath: screenshots.path)
            if let existing, !existing.isEmpty, !overwrite {
                // The repo already keeps screenshots here; the explanatory README
                // would just be noise.
                skipped.append(".dockyard/screenshots/README.md")
            } else {
                try FileManager.default.createDirectory(at: screenshots, withIntermediateDirectories: true)
                try put(Data(Self.screenshotsReadme.utf8), at: ".dockyard/screenshots/README.md")
            }
        }

        return Result(root: root, files: files, skipped: skipped)
    }

    /// A fresh temp directory to scaffold into, e.g.
    /// `<tmp>/dockyard-scaffold/apparata-widget-mac`. Any leftovers from a previous
    /// run of the same repo are cleared first.
    static func temporaryRoot(owner: String, repo: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "dockyard-scaffold")
            .appending(path: "\(owner)-\(repo)")
        try? FileManager.default.removeItem(at: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func aboutTemplate(displayName: String) -> String {
        """
        # \(displayName)

        TODO: Describe \(displayName) here. This file is rendered as the "About"
        section of the app's page in Dockyard, so write it for someone deciding
        whether to install it: what the app does, who it's for, what makes it
        worth having.

        Markdown is supported. Delete this file if you'd rather have no About section.
        """
    }

    static let screenshotsReadme = """
        # Screenshots

        Drop screenshots in this folder as `01.png`, `02.png`, ... — they appear in
        the app's "Screenshots" section in Dockyard, sorted alphabetically by filename.

        - Size them **680×420 pixels** (340×210 points @2x) so they render crisp.
        - Only `.png`, `.jpg`, `.jpeg`, `.gif` and `.webp` are picked up; this README
          is ignored by the manifest build.
        - The section is omitted entirely if the folder has no images.
        """
}
