//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

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
    @State private var navigationPath = NavigationPath()

    private var entries: [CatalogEntry] {
        guard let category else { return engine.catalog }
        return engine.catalog.filter { $0.category == category }
    }

    var body: some View {
        Pane {
            NavigationStack(path: $navigationPath) {
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
                .navigationDestination(for: CatalogEntry.self) { entry in
                    AppDetailsView(entry)
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
            AppCardFactory.makeItem(
                for: entry,
                engine: engine,
                iconURL: iconURLs[entry.id],
                onOpenDetails: { navigationPath.append(entry) }
            )
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
