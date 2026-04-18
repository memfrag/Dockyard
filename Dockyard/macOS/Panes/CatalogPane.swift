//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import AppKit
import SwiftUI
import SwiftUIToolbox
import AppDesign
import DockyardEngine

struct CatalogPane: View {

    let title: String
    let category: String?
    let sectionTitle: String
    let emptyTitle: String
    let emptyMessage: String
    let subtitle: (DockyardEngine, [CatalogEntry]) -> String

    @Environment(DockyardEngine.self) private var engine

    @State private var iconURLs: [CatalogEntry.ID: URL] = [:]

    private var entries: [CatalogEntry] {
        guard let category else { return engine.catalog }
        return engine.catalog.filter { $0.category == category }
    }

    var body: some View {
        Pane {
            NavigationStack {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 20) {
                        PaneHeader(title, subtitle: "Category", description: subtitle(engine, entries))

                        if entries.isEmpty {
                            emptyState
                        } else {
                            AppCardGrid(items: cardItems)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(32)
                }
            }
        }
        .navigationTitle(title)
        .task(id: entries.map(\.id)) {
            await loadIcons()
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(emptyTitle)
                .font(.headline)
            Text(emptyMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Card mapping

    private var cardItems: [AppCardItem] {
        entries.map { entry in
            AppCardItem(
                id: entry.id,
                icon: iconSource(for: entry),
                category: entry.category,
                title: entry.displayName,
                description: entry.summary,
                actionTitle: actionTitle(for: entry),
                actionEnabled: actionEnabled(for: entry),
                progress: (engine.phases[entry.id] ?? .idle).downloadFraction,
                action: { performAction(for: entry) }
            )
        }
    }

    private func iconSource(for entry: CatalogEntry) -> AppIconSource {
        if let url = iconURLs[entry.id] {
            return .file(url)
        }
        return .symbol(name: "app.dashed", background: Color.gray.opacity(0.25), foreground: .secondary)
    }

    // MARK: - Action state

    private func installedApp(for entry: CatalogEntry) -> InstalledApp? {
        engine.installations.first(where: { $0.id == entry.id })
    }

    private func actionTitle(for entry: CatalogEntry) -> String {
        if installedApp(for: entry) != nil {
            return "Open"
        }
        switch engine.phases[entry.id] ?? .idle {
        case .queued:
            return "Queued"
        case .downloadingDMG(let progress):
            if let f = progress.fraction {
                return "\(Int(f * 100))%"
            }
            return "…"
        case .verifyingHash, .mounting, .copying, .verifyingSignature, .finalizing:
            return "Installing…"
        case .cancelled, .failed:
            return "Retry"
        case .idle, .installed:
            return installedApp(for: entry) != nil ? "Open" : "Install"
        }
    }

    private func actionEnabled(for entry: CatalogEntry) -> Bool {
        if installedApp(for: entry) != nil { return true }
        return !(engine.phases[entry.id]?.isInFlight ?? false)
    }

    private func performAction(for entry: CatalogEntry) {
        if let installed = installedApp(for: entry) {
            NSWorkspace.shared.open(installed.bundlePath)
            return
        }
        Task {
            _ = try? await engine.install(entry.id)
        }
    }

    // MARK: - Icon preload

    private func loadIcons() async {
        for entry in entries where iconURLs[entry.id] == nil {
            if let url = try? await engine.iconFile(for: entry.id) {
                iconURLs[entry.id] = url
            }
        }
    }

    // MARK: - Shared subtitle helpers

    static func countSubtitle(engine: DockyardEngine, entries: [CatalogEntry]) -> String {
        let count = entries.count
        if count == 0 { return "No apps yet" }
        return "\(count) app\(count == 1 ? "" : "s") in this category."
    }
}
