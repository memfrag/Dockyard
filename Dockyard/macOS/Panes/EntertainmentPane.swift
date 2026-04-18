//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftUIToolbox

struct EntertainmentPane: View {

    var body: some View {
        Pane {
            VStack(spacing: 20) {
                Text("Entertainment")
            }
        }
        .navigationTitle("Entertainment")
    }
}

#Preview {
    EntertainmentPane()
}
