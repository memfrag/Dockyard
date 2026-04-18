//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import AppDesign

struct SidebarFooter: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.horizontal, 8)
            UserBadge()
                .padding(16)
        }
    }
}

#Preview {
    SidebarFooter()
        .frame(width: 250)
}
