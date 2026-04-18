//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftUIToolbox

struct ProductivityPane: View {

    var body: some View {
        Pane {
            VStack(spacing: 20) {
                Text("Productivity")
            }
        }
        .navigationTitle("Productivity")
    }
}

#Preview {
    ProductivityPane()
}
