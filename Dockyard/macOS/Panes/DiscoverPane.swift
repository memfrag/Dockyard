//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import DockyardEngine

struct DiscoverPane: View {

    var body: some View {
        CatalogPane(
            title: "Discover",
            category: nil,
            sectionTitle: "Available apps",
            emptyTitle: "No apps available yet",
            emptyMessage: "Waiting on the first catalog refresh.",
            subtitle: Self.subtitle
        )
    }

    private static func subtitle(engine: DockyardEngine, entries: [CatalogEntry]) -> String {
        if let date = engine.lastSuccessfulRefresh {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            let relative = formatter.localizedString(for: date, relativeTo: Date())
            if engine.catalogIsStale {
                return "Updated \(relative) (offline)"
            } else {
                return "Filter by category from the sidebar."
            }
        }
        return engine.catalogIsStale ? "Offline — showing cached catalog" : "Loading…"
    }
}

#Preview {
    DiscoverPane()
        .previewEnvironment()
}
