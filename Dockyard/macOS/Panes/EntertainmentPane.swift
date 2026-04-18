//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI

struct EntertainmentPane: View {

    var body: some View {
        CatalogPane(
            title: "Entertainment",
            category: "Entertainment",
            sectionTitle: "Available apps",
            emptyTitle: "No entertainment apps yet",
            emptyMessage: "Entertainment apps will appear here.",
            subtitle: CatalogPane.countSubtitle
        )
    }
}

#Preview {
    EntertainmentPane()
        .previewEnvironment()
}
