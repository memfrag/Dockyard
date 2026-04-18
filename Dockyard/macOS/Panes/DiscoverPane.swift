//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftUIToolbox

struct DiscoverPane: View {

    var body: some View {
        Pane {
            VStack(spacing: 20) {
                Text("Discover")
            }
        }
        .navigationTitle("Discover")
    }
}

#Preview {
    DiscoverPane()
}
