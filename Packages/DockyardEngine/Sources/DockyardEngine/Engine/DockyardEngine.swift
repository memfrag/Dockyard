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

    // MARK: - Dependencies

    @ObservationIgnored private let manifestURL: URL
    @ObservationIgnored private let editorialURL: URL
    @ObservationIgnored private let loader: CatalogLoader
    @ObservationIgnored private let cache: CatalogCache
    @ObservationIgnored private let editorialLoader: EditorialLoader
    @ObservationIgnored private let editorialCache: EditorialCache
    @ObservationIgnored private let iconCache: IconCache
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

    // MARK: - Init

    public init(
        manifestURL: URL,
        editorialURL: URL,
        installRoot: URL = InstallDestination.userApplications,
        iconCacheDirectory: URL = IconCache.defaultDirectory,
        urlSession: URLSession = .shared
    ) {
        self.manifestURL = manifestURL
        self.editorialURL = editorialURL
        self.loader = CatalogLoader(urlSession: urlSession)
        self.cache = CatalogCache()
        self.editorialLoader = EditorialLoader(urlSession: urlSession)
        self.editorialCache = EditorialCache()
        self.iconCache = IconCache(directory: iconCacheDirectory, urlSession: urlSession)
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
        Task { await self.crashCleanup.run() }
        Logger.engine.info("DockyardEngine initialized (manifestURL: \(manifestURL.absoluteString, privacy: .public), cached catalog: \(self.catalog.count), installations: \(self.installations.count))")
    }

    // MARK: - Public API

    public func refreshCatalog() async throws {
        Logger.catalog.info("refreshCatalog starting: \(self.manifestURL.absoluteString, privacy: .public)")
        do {
            let manifest = try await loader.load(from: manifestURL)
            catalog = manifest.apps
            lastSuccessfulRefresh = Date()
            catalogIsStale = false
            do { try cache.save(manifest) } catch {
                Logger.catalog.warning("Could not write catalog cache: \(String(describing: error), privacy: .public)")
            }
            Logger.catalog.info("refreshCatalog succeeded: \(manifest.apps.count) apps (generatedAt: \(manifest.generatedAt, privacy: .public))")
            if needsDiskRebuild {
                rebuildInstallationsFromDisk()
                needsDiskRebuild = false
            }
        } catch {
            catalogIsStale = true
            Logger.catalog.error("refreshCatalog failed: \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    public func refreshEditorial() async throws {
        Logger.catalog.info("refreshEditorial starting: \(self.editorialURL.absoluteString, privacy: .public)")
        do {
            let loaded = try await editorialLoader.load(from: editorialURL)
            editorial = loaded
            lastSuccessfulEditorialRefresh = Date()
            editorialIsStale = false
            do { try editorialCache.save(loaded) } catch {
                Logger.catalog.warning("Could not write editorial cache: \(String(describing: error), privacy: .public)")
            }
            Logger.catalog.info("refreshEditorial succeeded (generatedAt: \(loaded.generatedAt, privacy: .public))")
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
