//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI

struct FinancePane: View {

    var body: some View {
        CatalogPane(
            title: "Finance",
            category: "Finance",
            sectionTitle: "Available apps",
            emptyTitle: "No finance apps yet",
            emptyMessage: "Finance apps will appear here.",
            subtitle: CatalogPane.countSubtitle
        )
    }
}

#if DEBUG
#Preview {
    FinancePane()
        .previewEnvironment()
}
#endif
