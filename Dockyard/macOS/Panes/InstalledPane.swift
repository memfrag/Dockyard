//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import AppKit
import SwiftUI
import SwiftUIToolbox
import AppDesign
import DockyardEngine

struct InstalledPane: View {

    @Environment(DockyardEngine.self) private var engine

    @State private var iconURLs: [CatalogEntry.ID: URL] = [:]
    @State private var uninstallTarget: InstalledApp?
    @State private var navigationPath = NavigationPath()

    var body: some View {
        Pane {
            NavigationStack(path: $navigationPath) {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 20) {
                        PaneHeader(
                            "Installed",
                            subtitle: "\(engine.installations.count) app\(engine.installations.count == 1 ? "" : "s") in ~/Applications",
                            description: "Right-click an app for the option to uninstall it."
                        )

                        if engine.installations.isEmpty {
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
        .navigationTitle("Installed")
        .task(id: engine.installations.map(\.id)) {
            await loadIcons()
        }
        .confirmationDialog(
            "Move \(uninstallTarget?.displayName ?? "app") to Trash?",
            isPresented: Binding(
                get: { uninstallTarget != nil },
                set: { if !$0 { uninstallTarget = nil } }
            ),
            presenting: uninstallTarget
        ) { app in
            Button("Move to Trash", role: .destructive) {
                Task { try? await engine.uninstall(app.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("The app will be moved to the Trash and removed from Dockyard's installed list.")
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing installed yet")
                .font(.headline)
            Text("Install an app from Discover and it will show up here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Card mapping

    private var cardItems: [AppCardItem] {
        engine.installations.map { installed in
            let entry = engine.catalog.first(where: { $0.id == installed.id })
            let actionTitle: String
            let actionEnabled: Bool
            let progress: Double?
            let action: () -> Void
            if let entry {
                actionTitle = AppCardFactory.actionTitle(for: entry, engine: engine)
                actionEnabled = AppCardFactory.actionEnabled(for: entry, engine: engine)
                progress = (engine.phases[entry.id] ?? .idle).downloadFraction
                action = { AppCardFactory.performAction(for: entry, engine: engine) }
            } else {
                actionTitle = "Open"
                actionEnabled = true
                progress = nil
                action = { NSWorkspace.shared.open(installed.bundlePath) }
            }
            return AppCardItem(
                id: installed.id,
                icon: iconSource(for: installed),
                category: entry?.category ?? "Installed",
                title: installed.displayName,
                description: "Version \(installed.version)",
                channel: entry?.channel.stringIfNotRelease,
                actionTitle: actionTitle,
                actionEnabled: actionEnabled,
                progress: progress,
                action: action,
                menuItems: [
                    AppCardMenuItem(
                        title: "Show in Finder",
                        systemImage: "folder"
                    ) {
                        NSWorkspace.shared.activateFileViewerSelecting([installed.bundlePath])
                    },
                    AppCardMenuItem(
                        title: "Uninstall…",
                        systemImage: "trash",
                        isDestructive: true
                    ) {
                        uninstallTarget = installed
                    }
                ],
                onOpenDetails: entry.map { resolved in
                    { navigationPath.append(resolved) }
                }
            )
        }
    }

    private func iconSource(for installed: InstalledApp) -> AppIconSource {
        if let url = iconURLs[installed.id] {
            return .file(url)
        }
        return .symbol(name: "app.dashed", background: Color.gray.opacity(0.25), foreground: .secondary)
    }

    // MARK: - Icon preload

    private func loadIcons() async {
        for app in engine.installations where iconURLs[app.id] == nil {
            if let url = try? await engine.iconFile(for: app.id) {
                iconURLs[app.id] = url
            }
        }
    }
}

#if DEBUG
#Preview {
    InstalledPane()
        .previewEnvironment()
}
#endif
