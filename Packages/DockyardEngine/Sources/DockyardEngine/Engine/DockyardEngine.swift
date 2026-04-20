import AppKit
import Foundation
import Observation
import os

@MainActor
@Observable
public final class DockyardEngine {

    // MARK: - Observable state

    public private(set) var catalog: [CatalogEntry] = []
    public private(set) var installations: [InstalledApp] = []
    public private(set) var phases: [CatalogEntry.ID: InstallPhase] = [:]
    public private(set) var lastSuccessfulRefresh: Date?
    public private(set) var catalogIsStale: Bool = false

    public private(set) var editorial: Editorial?
    public private(set) var lastSuccessfulEditorialRefresh: Date?
    public private(set) var editorialIsStale: Bool = false

    /// Bundle identifiers of apps currently running in the user session. Kept in sync
    /// via AppKit's `didLaunchApplicationNotification` / `didTerminateApplicationNotification`.
    public private(set) var runningAppBundleIDs: Set<String> = []

    // MARK: - Dependencies

    @ObservationIgnored private let manifestURL: URL
    @ObservationIgnored private let editorialURL: URL
    @ObservationIgnored private let loader: CatalogLoader
    @ObservationIgnored private let cache: CatalogCache
    @ObservationIgnored private let editorialLoader: EditorialLoader
    @ObservationIgnored private let editorialCache: EditorialCache
    @ObservationIgnored private let iconCache: IconCache
    @ObservationIgnored private let screenshotCache: ScreenshotCache
    @ObservationIgnored private let aboutCache: AboutCache
    @ObservationIgnored private let installer: Installer
    @ObservationIgnored private let mounter: DMGMounting
    @ObservationIgnored private let crashCleanup: CrashCleanup
    @ObservationIgnored private let installedStore: InstalledAppsStore
    @ObservationIgnored private let reconciler: InstalledAppsReconciler
    @ObservationIgnored private let installRoot: URL

    // MARK: - Install queue + coalescing

    @ObservationIgnored private var queueTail: Task<Void, Never> = Task {}
    @ObservationIgnored private var inFlight: [CatalogEntry.ID: Task<InstalledApp, Error>] = [:]
    @ObservationIgnored private var cancelFlags: [CatalogEntry.ID: CancelFlag] = [:]

    // MARK: - Disk-rebuild deferral

    @ObservationIgnored private var needsDiskRebuild: Bool = false

    // MARK: - Staleness throttle

    @ObservationIgnored private var lastRefreshAttempt: Date?

    // MARK: - Running-app observation

    @ObservationIgnored private var workspaceObservers: [NSObjectProtocol] = []

    // MARK: - Init

    public init(
        manifestURL: URL,
        editorialURL: URL,
        installRoot: URL = InstallDestination.userApplications,
        iconCacheDirectory: URL = IconCache.defaultDirectory,
        screenshotCacheDirectory: URL = ScreenshotCache.defaultDirectory,
        aboutCacheDirectory: URL = AboutCache.defaultDirectory,
        urlSession: URLSession = .shared
    ) {
        self.manifestURL = manifestURL
        self.editorialURL = editorialURL
        self.loader = CatalogLoader(urlSession: urlSession)
        self.cache = CatalogCache()
        self.editorialLoader = EditorialLoader(urlSession: urlSession)
        self.editorialCache = EditorialCache()
        self.iconCache = IconCache(directory: iconCacheDirectory, urlSession: urlSession)
        self.screenshotCache = ScreenshotCache(directory: screenshotCacheDirectory, urlSession: urlSession)
        self.aboutCache = AboutCache(directory: aboutCacheDirectory, urlSession: urlSession)
        self.installer = Installer(
            downloader: Downloader(urlSession: urlSession),
            installRoot: installRoot
        )
        self.mounter = DMGMounter()
        self.crashCleanup = CrashCleanup()
        self.installedStore = InstalledAppsStore()
        self.reconciler = InstalledAppsReconciler(installRoot: installRoot)
        self.installRoot = installRoot

        loadCachedCatalog()
        loadCachedEditorial()
        loadInstallations()
        seedRunningApps()
        installWorkspaceObservers()
        Task { await self.crashCleanup.run() }
        Logger.engine.info("DockyardEngine initialized (manifestURL: \(manifestURL.absoluteString, privacy: .public), cached catalog: \(self.catalog.count), installations: \(self.installations.count))")
    }

    // `workspaceObservers` intentionally does not have a deinit-cleanup step:
    // the engine's lifetime is the app's lifetime, and accessing main-actor
    // state from a nonisolated deinit trips strict-concurrency checks.

    // MARK: - Public API

    public func refreshCatalog() async throws {
        Logger.catalog.info("refreshCatalog starting: \(self.manifestURL.absoluteString, privacy: .public)")
        do {
            let manifest = try await loader.load(from: manifestURL)
            if catalogIsStale {
                catalogIsStale = false
            }
            if catalog == manifest.apps {
                Logger.catalog.info("refreshCatalog: no changes; leaving data model untouched")
            } else {
                catalog = manifest.apps
                lastSuccessfulRefresh = Date()
                do { try cache.save(manifest) } catch {
                    Logger.catalog.warning("Could not write catalog cache: \(String(describing: error), privacy: .public)")
                }
                Logger.catalog.info("refreshCatalog succeeded: \(manifest.apps.count) apps (generatedAt: \(manifest.generatedAt, privacy: .public))")
                if needsDiskRebuild {
                    rebuildInstallationsFromDisk()
                    needsDiskRebuild = false
                }
            }
        } catch {
            catalogIsStale = true
            Logger.catalog.error("refreshCatalog failed: \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    /// Refreshes catalog + editorial in parallel, but only if at least
    /// `minInterval` seconds have elapsed since the last attempt. Use this
    /// from app-focus and menu-refresh triggers to avoid hammering the network.
    ///
    /// Errors from the underlying refresh calls are swallowed (the existing
    /// `catalogIsStale` / `editorialIsStale` flags already surface failure to the UI).
    public func refreshIfStale(minInterval: TimeInterval) async {
        if let last = lastRefreshAttempt, Date().timeIntervalSince(last) < minInterval {
            return
        }
        lastRefreshAttempt = Date()
        async let catalog: Void = {
            try? await self.refreshCatalog()
        }()
        async let editorial: Void = {
            try? await self.refreshEditorial()
        }()
        _ = await (catalog, editorial)
    }

    public func refreshEditorial() async throws {
        Logger.catalog.info("refreshEditorial starting: \(self.editorialURL.absoluteString, privacy: .public)")
        do {
            let loaded = try await editorialLoader.load(from: editorialURL)
            if editorialIsStale {
                editorialIsStale = false
            }
            if editorial == loaded {
                Logger.catalog.info("refreshEditorial: no changes; leaving data model untouched")
            } else {
                editorial = loaded
                lastSuccessfulEditorialRefresh = Date()
                do { try editorialCache.save(loaded) } catch {
                    Logger.catalog.warning("Could not write editorial cache: \(String(describing: error), privacy: .public)")
                }
                Logger.catalog.info("refreshEditorial succeeded (generatedAt: \(loaded.generatedAt, privacy: .public))")
            }
        } catch {
            editorialIsStale = true
            Logger.catalog.error("refreshEditorial failed: \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    public func iconFile(for appID: CatalogEntry.ID) async throws -> URL {
        guard let entry = catalog.first(where: { $0.id == appID }) else {
            throw EngineError.notInstalled(id: appID)
        }
        return try await iconCache.localFile(for: entry.iconURL)
    }

    /// Returns the local file URL for a screenshot, downloading and caching it
    /// on first request. Subsequent requests for the same URL return the cached
    /// file without hitting the network.
    public func screenshotFile(for url: URL) async throws -> URL {
        try await screenshotCache.localFile(for: url)
    }

    /// Returns the local file URL for an About markdown file, downloading and
    /// caching it on first request. Subsequent requests for the same URL return
    /// the cached file without hitting the network.
    public func aboutFile(for url: URL) async throws -> URL {
        try await aboutCache.localFile(for: url)
    }

    public func install(_ appID: CatalogEntry.ID) async throws -> InstalledApp {
        if let existing = inFlight[appID] {
            return try await existing.value
        }
        guard let entry = catalog.first(where: { $0.id == appID }) else {
            throw EngineError.notInstalled(id: appID)
        }

        let flag = CancelFlag()
        cancelFlags[appID] = flag
        phases[appID] = .queued

        let priorTail = queueTail

        let task = Task<InstalledApp, Error> { [weak self] in
            _ = await priorTail.value
            guard let self else { throw EngineError.cancelled }
            if flag.isCancelled {
                self.setPhase(appID, .cancelled)
                self.clearInFlight(appID)
                throw EngineError.cancelled
            }
            do {
                let installed = try await self.performInstall(entry, cancelFlag: flag)
                self.setPhase(appID, .installed)
                self.clearInFlight(appID)
                return installed
            } catch let engineError as EngineError {
                let finalPhase: InstallPhase = engineError == .cancelled ? .cancelled : .failed(engineError)
                self.setPhase(appID, finalPhase)
                self.clearInFlight(appID)
                throw engineError
            } catch is CancellationError {
                self.setPhase(appID, .cancelled)
                self.clearInFlight(appID)
                throw EngineError.cancelled
            } catch {
                let wrapped = EngineError.fileSystemError(underlying: String(describing: error))
                self.setPhase(appID, .failed(wrapped))
                self.clearInFlight(appID)
                throw wrapped
            }
        }

        inFlight[appID] = task
        queueTail = Task { _ = try? await task.value }
        return try await task.value
    }

    public func cancel(_ appID: CatalogEntry.ID) {
        cancelFlags[appID]?.cancel()
        inFlight[appID]?.cancel()
    }

    public func uninstall(_ appID: CatalogEntry.ID) async throws {
        guard let record = installations.first(where: { $0.id == appID }) else {
            throw EngineError.notInstalled(id: appID)
        }
        try await Self.recycle(record.bundlePath)
        var remaining = installations
        remaining.removeAll { $0.id == appID }
        installations = remaining
        do { try installedStore.save(remaining) } catch {
            throw EngineError.fileSystemError(underlying: String(describing: error))
        }
    }

    // MARK: - Helpers

    private func setPhase(_ id: CatalogEntry.ID, _ phase: InstallPhase) {
        phases[id] = phase
    }

    private func clearInFlight(_ id: CatalogEntry.ID) {
        inFlight[id] = nil
        cancelFlags[id] = nil
    }

    private func performInstall(_ entry: CatalogEntry, cancelFlag: CancelFlag) async throws -> InstalledApp {
        let existingRecord = installations.first(where: { $0.id == entry.id })
        let existingBundlePaths = Set(installations.map(\.bundlePath))

        let id = entry.id
        let result = try await installer.install(
            entry: entry,
            existingRecord: existingRecord,
            existingBundlePaths: existingBundlePaths,
            isCancelled: { cancelFlag.isCancelled },
            onPhase: { [weak self] signal in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    switch signal {
                    case .downloadingDMG(let progress):
                        self.phases[id] = .downloadingDMG(progress)
                    case .verifyingHash:
                        self.phases[id] = .verifyingHash
                    case .mounting:
                        self.phases[id] = .mounting
                    case .copying:
                        self.phases[id] = .copying
                    case .verifyingSignature:
                        self.phases[id] = .verifyingSignature
                    case .finalizing:
                        self.phases[id] = .finalizing
                    }
                }
            }
        )

        var updated = installations
        updated.removeAll { $0.id == entry.id }
        updated.append(result.installedApp)
        installations = updated
        do {
            try installedStore.save(updated)
        } catch {
            throw EngineError.fileSystemError(underlying: String(describing: error))
        }

        if let orphaned = result.orphanedPriorBundlePath {
            Logger.installer.info("Orphan bundle left at \(orphaned.path, privacy: .public)")
        }
        return result.installedApp
    }

    /// Catalog entries whose installed version is strictly less than the version
    /// advertised in the catalog. Drives the sidebar Updates badge and the pane.
    public var entriesWithUpdatesAvailable: [CatalogEntry] {
        catalog.filter { entry in
            guard let installed = installations.first(where: { $0.id == entry.id }) else { return false }
            return installed.version.compare(entry.version, options: .numeric) == .orderedAscending
        }
    }

    // MARK: - Running-app observation

    private func seedRunningApps() {
        let identifiers = NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        runningAppBundleIDs = Set(identifiers)
    }

    private func installWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter
        let launch = center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { note in
            // `queue: .main` guarantees this runs on the main thread.
            // Extract only the Sendable String here, then hop to MainActor.
            guard let id = bundleID(from: note) else { return }
            Task { @MainActor [weak self] in
                self?.runningAppBundleIDs.insert(id)
            }
        }
        let terminate = center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { note in
            guard let id = bundleID(from: note) else { return }
            Task { @MainActor [weak self] in
                self?.runningAppBundleIDs.remove(id)
            }
        }
        workspaceObservers = [launch, terminate]
    }

    private func loadCachedCatalog() {
        if let cached = cache.load() {
            catalog = cached.apps
            lastSuccessfulRefresh = cached.generatedAt
            catalogIsStale = true
        }
    }

    private func loadCachedEditorial() {
        if let cached = editorialCache.load() {
            editorial = cached
            lastSuccessfulEditorialRefresh = cached.generatedAt
            editorialIsStale = true
        }
    }

    private func loadInstallations() {
        switch installedStore.load() {
        case .loaded(let apps):
            let pruned = reconciler.dropMissing(apps)
            installations = pruned
            if pruned.count != apps.count {
                try? installedStore.save(pruned)
            }
        case .empty:
            installations = []
        case .corrupt(_, let decodeError):
            Logger.tracking.error("installed.json corrupt: \(decodeError, privacy: .public)")
            _ = try? installedStore.quarantineCorrupt()
            installations = []
            needsDiskRebuild = true
        }
    }

    private func rebuildInstallationsFromDisk() {
        let rebuilt = reconciler.rebuildFromDisk(catalog: catalog)
        installations = rebuilt
        try? installedStore.save(rebuilt)
        Logger.tracking.info("Rebuilt installations from disk: \(rebuilt.count) apps")
    }

    // MARK: - NSWorkspace bridging

    private static func recycle(_ url: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.recycle([url]) { _, error in
                if let error {
                    continuation.resume(throwing: EngineError.fileSystemError(underlying: String(describing: error)))
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

/// Extracts the bundle identifier from an NSWorkspace launch/terminate notification.
/// Top-level so it can be called from a nonisolated notification closure without
/// capturing any actor-isolated state.
private func bundleID(from note: Notification) -> String? {
    (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
}
