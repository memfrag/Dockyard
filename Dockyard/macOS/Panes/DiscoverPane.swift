//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import AppKit
import SwiftUI
import SwiftUIToolbox
import AppDesign
import DockyardEngine

struct DiscoverPane: View {

    @Environment(DockyardEngine.self) private var engine

    @State private var iconURLs: [CatalogEntry.ID: URL] = [:]

    var body: some View {
        Pane {
            NavigationStack {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 20) {
                        header

                        PaneSection("Available apps") {
                            if engine.catalog.isEmpty {
                                emptyState
                            } else {
                                AppCardGrid(items: cardItems)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(32)
                }
            }
        }
        .navigationTitle("Discover")
        .task(id: engine.catalog.map(\.id)) {
            await loadIcons()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var header: some View {
        PaneHeader(
            "Discover",
            subtitle: subtitle
        )
    }

    private var subtitle: String {
        if let date = engine.lastSuccessfulRefresh {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            let relative = formatter.localizedString(for: date, relativeTo: Date())
            let stale = engine.catalogIsStale ? " (offline)" : ""
            return "Updated \(relative)\(stale)"
        }
        return engine.catalogIsStale ? "Offline — showing cached catalog" : "Loading…"
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No apps available yet")
                .font(.headline)
            Text("Waiting on the first catalog refresh.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Card mapping

    private var cardItems: [AppCardItem] {
        engine.catalog.map { entry in
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
        for entry in engine.catalog where iconURLs[entry.id] == nil {
            if let url = try? await engine.iconFile(for: entry.id) {
                iconURLs[entry.id] = url
            }
        }
    }
}

#Preview {
    DiscoverPane()
        .previewEnvironment()
}
