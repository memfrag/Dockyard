//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftUIToolbox

struct DevelopmentPane: View {

    var body: some View {
        Pane {
            VStack(spacing: 20) {
                Text("Development")
            }
        }
        .navigationTitle("Development")
    }
}

#Preview {
    DevelopmentPane()
}
