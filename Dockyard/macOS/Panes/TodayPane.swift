//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftUIToolbox
import AppDesign
import DockyardEngine

struct TodayPane: View {

    @Environment(DockyardEngine.self) private var engine

    @State private var iconURLs: [CatalogEntry.ID: URL] = [:]
    @State private var navigationPath = NavigationPath()

    var body: some View {
        Pane {
            NavigationStack(path: $navigationPath) {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                            .padding(.bottom, 16)

                        if let today = engine.editorial?.today {
                            todayContent(today)
                        } else {
                            emptyState
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
        .navigationTitle("Today")
        .task(id: referencedAppIDs) {
            await loadIcons()
        }
    }

    // MARK: - Header

    private var header: some View {
        PaneHeader(
            engine.editorial?.today?.title ?? "Today",
            subtitle: "Today · \(Date().weekdayDayMonth())"
        )
    }

    // MARK: - Content

    @ViewBuilder
    private func todayContent(_ today: TodayEditorial) -> some View {
        let heroEntry = today.editorsPick.flatMap { resolve($0.appID) }
        let resolvedHighlights = today.highlights.compactMap { highlight -> (HighlightItem, CatalogEntry)? in
            guard let entry = resolve(highlight.appID) else { return nil }
            return (highlight, entry)
        }

        if heroEntry != nil || !resolvedHighlights.isEmpty {
            heroRow(pick: today.editorsPick, heroEntry: heroEntry, highlights: resolvedHighlights)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 32)
        }

        ForEach(Array(today.sections.enumerated()), id: \.offset) { index, section in
            PaneSection(section.title, subtitle: section.subtitle) {
                AppCardGrid(items: section.appIDs.compactMap { id in
                    guard let entry = resolve(id) else { return nil }
                    return AppCardFactory.makeItem(
                        for: entry,
                        engine: engine,
                        iconURL: iconURLs[entry.id],
                        onOpenDetails: { navigationPath.append(entry) }
                    )
                })
            }
            .padding(.bottom, index == today.sections.count - 1 ? 0 : 32)
        }
    }

    @ViewBuilder
    private func heroRow(
        pick: EditorsPickItem?,
        heroEntry: CatalogEntry?,
        highlights: [(HighlightItem, CatalogEntry)]
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            if let pick, let heroEntry {
                EditorsPickBanner(
                    category: pick.category,
                    headline: pick.headline,
                    description: pick.description,
                    icon: iconSource(for: heroEntry),
                    appName: heroEntry.displayName,
                    appAuthor: "Version \(heroEntry.version)",
                    gradient: gradient(from: pick.gradient),
                    actionTitle: AppCardFactory.actionTitle(for: heroEntry, engine: engine),
                    actionEnabled: AppCardFactory.actionEnabled(for: heroEntry, engine: engine),
                    progress: (engine.phases[heroEntry.id] ?? .idle).downloadFraction,
                    onOpenDetails: { navigationPath.append(heroEntry) },
                    action: { AppCardFactory.performAction(for: heroEntry, engine: engine) }
                )
            }

            if !highlights.isEmpty {
                VStack(spacing: 16) {
                    ForEach(Array(highlights.enumerated()), id: \.offset) { _, pair in
                        let (highlight, entry) = pair
                        LargeAppCard(
                            icon: iconSource(for: entry),
                            category: highlight.category,
                            title: entry.displayName,
                            description: highlight.description,
                            channel: entry.channel.stringIfNotRelease,
                            onOpenDetails: { navigationPath.append(entry) }
                        )
                        .frame(maxHeight: .infinity)
                    }
                }
                .frame(width: 380)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today is taking a break")
                .font(.headline)
            Text("New editorial content will appear here soon.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Helpers

    private func resolve(_ id: CatalogEntry.ID) -> CatalogEntry? {
        engine.catalog.first(where: { $0.id == id })
    }

    private func iconSource(for entry: CatalogEntry) -> AppIconSource {
        AppCardFactory.iconSource(for: entry, iconURL: iconURLs[entry.id])
    }

    private func gradient(from hexValues: [String]) -> [Color] {
        let parsed = hexValues.compactMap { Color(hex: $0) }
        return parsed.count >= 2 ? parsed : EditorsPickBanner.defaultGradient
    }

    private var referencedAppIDs: [CatalogEntry.ID] {
        guard let today = engine.editorial?.today else { return [] }
        var ids: [CatalogEntry.ID] = []
        if let pick = today.editorsPick { ids.append(pick.appID) }
        ids.append(contentsOf: today.highlights.map(\.appID))
        ids.append(contentsOf: today.sections.flatMap(\.appIDs))
        return ids
    }

    private func loadIcons() async {
        for id in referencedAppIDs where iconURLs[id] == nil {
            if let url = try? await engine.iconFile(for: id) {
                iconURLs[id] = url
            }
        }
    }
}

#Preview {
    TodayPane()
        .previewEnvironment()
}
