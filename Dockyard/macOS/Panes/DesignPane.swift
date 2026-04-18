//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftUIToolbox

struct DesignPane: View {

    var body: some View {
        Pane {
            NavigationStack {
                VStack(spacing: 20) {
                    Text("Design")
                }
            }
        }
        .navigationTitle("Design")
    }
}

#Preview {
    DesignPane()
}
