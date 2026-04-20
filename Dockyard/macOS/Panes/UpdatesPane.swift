//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import DockyardEngine

struct UpdatesPane: View {

    @Environment(DockyardEngine.self) private var engine

    var body: some View {
        let updatableIDs = Set(engine.entriesWithUpdatesAvailable.map(\.id))
        CatalogPane(
            title: "Updates",
            category: nil,
            sectionTitle: "Available updates",
            emptyTitle: "You're all up to date",
            emptyMessage: "Installed apps with available updates will appear here.",
            subtitle: { _, entries in
                let count = entries.count
                if count == 0 { return "No updates available" }
                return "\(count) update\(count == 1 ? "" : "s") available"
            },
            pretitle: "Installed",
            extraFilter: { updatableIDs.contains($0.id) }
        )
    }
}

#if DEBUG
#Preview {
    UpdatesPane()
        .previewEnvironment()
}
#endif
