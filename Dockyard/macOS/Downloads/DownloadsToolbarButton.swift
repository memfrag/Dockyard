//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import DockyardEngine

struct DownloadsToolbarButton: View {

    @Environment(DockyardEngine.self) private var engine
    @State private var isPresented: Bool = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "arrow.down.circle")
                if activeCount > 0 {
                    Text("\(activeCount)")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.red, in: Capsule())
                        .foregroundStyle(.white)
                        .offset(x: 8, y: -6)
                }
            }
        }
        .help(activeCount > 0 ? "\(activeCount) active download\(activeCount == 1 ? "" : "s")" : "Downloads")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            DownloadsPopover()
        }
    }

    private var activeCount: Int {
        engine.phases.values.filter(\.isInFlight).count
    }
}
