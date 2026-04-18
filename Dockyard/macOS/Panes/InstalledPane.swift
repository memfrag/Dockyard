//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftUIToolbox

struct InstalledPane: View {

    var body: some View {
        Pane {
            VStack(spacing: 20) {
                Text("Installed")
            }
        }
        .navigationTitle("Installed")
    }
}

#Preview {
    InstalledPane()
}
