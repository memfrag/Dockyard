//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI

struct ProductivityPane: View {

    var body: some View {
        CatalogPane(
            title: "Productivity",
            category: "Productivity",
            sectionTitle: "Available apps",
            emptyTitle: "No productivity apps yet",
            emptyMessage: "Productivity apps will appear here.",
            subtitle: CatalogPane.countSubtitle
        )
    }
}

#if DEBUG
#Preview {
    ProductivityPane()
        .previewEnvironment()
}
#endif
