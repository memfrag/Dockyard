//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import AppKit
import SwiftUI
import AppDesign
import DockyardEngine

enum AppCardFactory {

    static func makeItem(
        for entry: CatalogEntry,
        engine: DockyardEngine,
        iconURL: URL?,
        onOpenDetails: (() -> Void)? = nil
    ) -> AppCardItem {
        AppCardItem(
            id: entry.id,
            icon: iconSource(for: entry, iconURL: iconURL),
            category: entry.category,
            title: entry.displayName,
            description: entry.summary,
            channel: entry.channel.stringIfNotRelease,
            actionTitle: actionTitle(for: entry, engine: engine),
            actionEnabled: actionEnabled(for: entry, engine: engine),
            progress: (engine.phases[entry.id] ?? .idle).downloadFraction,
            action: { performAction(for: entry, engine: engine) },
            onOpenDetails: onOpenDetails
        )
    }

    static func iconSource(for entry: CatalogEntry, iconURL: URL?) -> AppIconSource {
        if let iconURL {
            return .file(iconURL)
        }
        return .symbol(name: "app.dashed", background: Color.gray.opacity(0.25), foreground: .secondary)
    }

    static func installedApp(for entry: CatalogEntry, engine: DockyardEngine) -> InstalledApp? {
        engine.installations.first(where: { $0.id == entry.id })
    }

    /// True when the app is installed and the catalog advertises a newer version
    /// than what's currently on disk.
    static func updateAvailable(for entry: CatalogEntry, engine: DockyardEngine) -> Bool {
        guard let installed = installedApp(for: entry, engine: engine) else { return false }
        return installed.version.compare(entry.version, options: .numeric) == .orderedAscending
    }

    /// True when the app's bundle is currently running in the user session.
    static func isRunning(_ entry: CatalogEntry, engine: DockyardEngine) -> Bool {
        engine.runningAppBundleIDs.contains(entry.id)
    }

    static func actionTitle(for entry: CatalogEntry, engine: DockyardEngine) -> String {
        // In-flight install phases take precedence.
        switch engine.phases[entry.id] ?? .idle {
        case .queued:
            return "Queued"
        case .downloadingDMG(let progress):
            if let fraction = progress.fraction {
                return "\(Int(fraction * 100))%"
            }
            return "…"
        case .verifyingHash, .mounting, .copying, .verifyingSignature, .finalizing:
            return "Installing…"
        case .cancelled, .failed:
            return "Retry"
        case .idle, .installed:
            break
        }

        guard installedApp(for: entry, engine: engine) != nil else {
            return "Install"
        }
        if updateAvailable(for: entry, engine: engine) {
            return isRunning(entry, engine: engine) ? "Quit to Update" : "Update"
        }
        return "Open"
    }

    static func actionEnabled(for entry: CatalogEntry, engine: DockyardEngine) -> Bool {
        if engine.phases[entry.id]?.isInFlight == true {
            return false
        }
        // "Quit to Update" — running app blocks the install; disable the button.
        if installedApp(for: entry, engine: engine) != nil,
           updateAvailable(for: entry, engine: engine),
           isRunning(entry, engine: engine) {
            return false
        }
        return true
    }

    static func performAction(for entry: CatalogEntry, engine: DockyardEngine) {
        if let installed = installedApp(for: entry, engine: engine) {
            if updateAvailable(for: entry, engine: engine), !isRunning(entry, engine: engine) {
                install(entry, engine: engine)
                return
            }
            NSWorkspace.shared.open(installed.bundlePath)
            return
        }
        install(entry, engine: engine)
    }

    private static func install(_ entry: CatalogEntry, engine: DockyardEngine) {
        Task {
            do {
                _ = try await engine.install(entry.id)
            } catch {
                let reason = (error as? LocalizedError)?.errorDescription
                    ?? String(describing: error)
                print("[Dockyard] Install failed for \(entry.id): \(reason)")
            }
        }
    }
}
