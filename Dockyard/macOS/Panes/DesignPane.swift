//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI

struct DesignPane: View {

    var body: some View {
        CatalogPane(
            title: "Design",
            category: "Design",
            sectionTitle: "Available apps",
            emptyTitle: "No design apps yet",
            emptyMessage: "Design apps will appear here.",
            subtitle: CatalogPane.countSubtitle
        )
    }
}

#if DEBUG
#Preview {
    DesignPane()
        .previewEnvironment()
}
#endif
