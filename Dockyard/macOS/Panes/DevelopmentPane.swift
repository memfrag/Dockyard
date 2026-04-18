//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI

struct DevelopmentPane: View {

    var body: some View {
        CatalogPane(
            title: "Development",
            category: "Development",
            sectionTitle: "Available apps",
            emptyTitle: "No development apps yet",
            emptyMessage: "Development apps will appear here.",
            subtitle: CatalogPane.countSubtitle
        )
    }
}

#Preview {
    DevelopmentPane()
        .previewEnvironment()
}
