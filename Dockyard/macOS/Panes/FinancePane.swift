//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftUIToolbox

struct FinancePane: View {

    var body: some View {
        Pane {
            VStack(spacing: 20) {
                Text("Finance")
            }
        }
        .navigationTitle("Finance")
    }
}

#Preview {
    FinancePane()
}
