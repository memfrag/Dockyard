import CryptoKit
import Foundation
import os

struct InstallResult: Sendable {
    let installedApp: InstalledApp
    /// The prior installed path if the bundle filename changed between versions.
    let orphanedPriorBundlePath: URL?
}

enum InstallerPhaseSignal: Sendable {
    case downloadingDMG(DownloadProgress)
    case verifyingHash
    case mounting
    case copying
    case verifyingSignature
    case finalizing
}

struct Installer: Sendable {

    let downloader: Downloader
    let mounter: DMGMounting
    let verifier: CodesignVerifying
    let installRoot: URL
    let tempRoot: URL

    init(
        downloader: Downloader = Downloader(),
        mounter: DMGMounting = DMGMounter(),
        verifier: CodesignVerifying = CodesignVerifier(),
        installRoot: URL = InstallDestination.userApplications,
        tempRoot: URL = CrashCleanup.defaultTempRoot
    ) {
        self.downloader = downloader
        self.mounter = mounter
        self.verifier = verifier
        self.installRoot = installRoot
        self.tempRoot = tempRoot
    }

    /// Runs the full install pipeline.
    ///
    /// - Parameters:
    ///   - entry: The manifest entry to install.
    ///   - existingRecord: The current `InstalledApp` record for `entry.id`, if any. Used for
    ///     the destination-occupied check and bundle-rename handling.
    ///   - existingBundlePaths: All currently tracked bundle paths (to check destination ownership).
    ///   - isCancelled: Called between steps. Returning `true` aborts with `.cancelled`.
    ///   - onPhase: Published once per step transition.
    func install(
        entry: CatalogEntry,
        existingRecord: InstalledApp?,
        existingBundlePaths: Set<URL>,
        isCancelled: @Sendable @escaping () -> Bool,
        onPhase: @Sendable @escaping (InstallerPhaseSignal) -> Void
    ) async throws -> InstallResult {

        // 1. Pre-check destination — by display name bundle filename
        let destination = installRoot.appending(path: "\(entry.displayName).app")
        if FileManager.default.fileExists(atPath: destination.path),
           !existingBundlePaths.contains(destination) {
            throw EngineError.destinationOccupied(path: destination.path)
        }
        try InstallDestination.ensure(installRoot)

        try checkCancel(isCancelled)

        // 2. Download DMG
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let tempDMG = tempRoot.appending(path: "\(UUID().uuidString).dmg")
        onPhase(.downloadingDMG(DownloadProgress(bytesWritten: 0, bytesExpected: entry.dmgSize)))
        let downloaded: URL
        do {
            downloaded = try await downloader.download(from: entry.dmgURL) { progress in
                onPhase(.downloadingDMG(progress))
            }
        } catch {
            throw error
        }
        // URLSession.download returns a path the caller owns; move to our temp path.
        if downloaded != tempDMG {
            try? FileManager.default.removeItem(at: tempDMG)
            try FileManager.default.moveItem(at: downloaded, to: tempDMG)
        }

        defer { try? FileManager.default.removeItem(at: tempDMG) }

        try checkCancel(isCancelled)

        // 3. Hash
        if let expected = entry.dmgSHA256 {
            onPhase(.verifyingHash)
            let actual = try Self.sha256Hex(of: tempDMG)
            if actual.lowercased() != expected.lowercased() {
                throw EngineError.hashMismatch(expected: expected, actual: actual)
            }
        }

        try checkCancel(isCancelled)

        // 4. Mount
        onPhase(.mounting)
        let mountHandle = try await mounter.attach(tempDMG)
        var detached = false
        func detachOnce() async {
            guard !detached else { return }
            detached = true
            try? await mounter.detach(mountHandle)
        }
        do {
            // 5. Find .app
            let mountedApp = try Self.findApp(at: mountHandle.mountPoint)

            // 6. Validate bundle identifier (BEFORE copy — cheap fail)
            let mountedBundleID = try Self.bundleIdentifier(at: mountedApp)
            if mountedBundleID != entry.id {
                throw EngineError.bundleIdentifierMismatch(
                    expected: entry.id,
                    found: mountedBundleID
                )
            }

            try checkCancel(isCancelled)

            // 7. Copy — commit point
            onPhase(.copying)
            try Self.copyBundle(from: mountedApp, to: destination)

            // 8. Verify signature of the installed copy
            onPhase(.verifyingSignature)
            do {
                try await verifier.verify(destination)
            } catch {
                // Roll back the copy
                try? FileManager.default.removeItem(at: destination)
                throw error
            }

            // 9. Bundle rename handling — orphan prior bundle if filename changed
            var orphaned: URL?
            if let prior = existingRecord?.bundlePath, prior != destination {
                orphaned = prior
                Logger.installer.info(
                    "Bundle filename changed for \(entry.id, privacy: .public); old bundle orphaned at \(prior.path, privacy: .public)"
                )
            }

            // 10. Track
            onPhase(.finalizing)
            let version = (try? Self.shortVersion(at: destination)) ?? entry.version
            let installed = InstalledApp(
                id: entry.id,
                displayName: entry.displayName,
                version: version,
                bundlePath: destination,
                installedAt: Date()
            )
            await detachOnce()
            return InstallResult(installedApp: installed, orphanedPriorBundlePath: orphaned)
        } catch {
            await detachOnce()
            throw error
        }
    }

    // MARK: - Helpers

    private func checkCancel(_ isCancelled: () -> Bool) throws {
        if isCancelled() { throw EngineError.cancelled }
        try Task.checkCancellation()
    }

    static func findApp(at mountPoint: URL) throws -> URL {
        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: mountPoint,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw EngineError.fileSystemError(underlying: String(describing: error))
        }
        guard let app = contents.first(where: { $0.pathExtension == "app" }) else {
            throw EngineError.noAppInDMG
        }
        return app
    }

    static func bundleIdentifier(at bundleURL: URL) throws -> String {
        let info = bundleURL.appending(path: "Contents/Info.plist")
        guard let data = try? Data(contentsOf: info),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let bundleID = plist["CFBundleIdentifier"] as? String else {
            throw EngineError.fileSystemError(underlying: "Missing CFBundleIdentifier in \(info.path)")
        }
        return bundleID
    }

    static func shortVersion(at bundleURL: URL) throws -> String {
        let info = bundleURL.appending(path: "Contents/Info.plist")
        guard let data = try? Data(contentsOf: info),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let version = plist["CFBundleShortVersionString"] as? String else {
            throw EngineError.fileSystemError(underlying: "Missing CFBundleShortVersionString in \(info.path)")
        }
        return version
    }

    static func copyBundle(from source: URL, to destination: URL) throws {
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                // `replaceItemAt` uses `renamex_np` which fails with EXDEV
                // ("Cross-device link") when `source` is on a different filesystem
                // than `destination` — e.g. DMG mountpoint in /private/tmp vs.
                // ~/Applications on the user's home volume.
                //
                // Stage a copy on the destination's volume first so the replace is
                // intra-volume and can use rename semantics.
                let parent = destination.deletingLastPathComponent()
                let staged = parent.appending(
                    path: ".dockyard-staging-\(UUID().uuidString)-\(destination.lastPathComponent)"
                )
                try FileManager.default.copyItem(at: source, to: staged)
                do {
                    _ = try FileManager.default.replaceItemAt(destination, withItemAt: staged)
                } catch {
                    try? FileManager.default.removeItem(at: staged)
                    throw error
                }
            } else {
                // Fresh install — `copyItem` handles cross-device just fine.
                try FileManager.default.copyItem(at: source, to: destination)
            }
        } catch {
            throw EngineError.fileSystemError(underlying: String(describing: error))
        }
    }

    static func sha256Hex(of file: URL) throws -> String {
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: file)
        } catch {
            throw EngineError.fileSystemError(underlying: String(describing: error))
        }
        defer { try? handle.close() }

        var hasher = SHA256()
        while let chunk = try? handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
