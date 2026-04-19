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

    static func actionTitle(for entry: CatalogEntry, engine: DockyardEngine) -> String {
        if installedApp(for: entry, engine: engine) != nil {
            return "Open"
        }
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
            return installedApp(for: entry, engine: engine) != nil ? "Open" : "Install"
        }
    }

    static func actionEnabled(for entry: CatalogEntry, engine: DockyardEngine) -> Bool {
        if installedApp(for: entry, engine: engine) != nil { return true }
        return !(engine.phases[entry.id]?.isInFlight ?? false)
    }

    static func performAction(for entry: CatalogEntry, engine: DockyardEngine) {
        if let installed = installedApp(for: entry, engine: engine) {
            NSWorkspace.shared.open(installed.bundlePath)
            return
        }
        Task {
            _ = try? await engine.install(entry.id)
        }
    }
}
