//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import DockyardEngine

struct RefreshCatalogCommand: Commands {

    /// Minimum interval between manual menu-triggered refreshes.
    private static let menuRefreshCooldown: TimeInterval = 60

    var body: some Commands {
        CommandGroup(after: .sidebar) {
            Button("Refresh Catalog") {
                Task { @MainActor in
                    await AppEnvironment.default.dockyardEngine
                        .refreshIfStale(minInterval: Self.menuRefreshCooldown)
                }
            }
            .keyboardShortcut("r", modifiers: .command)
        }
    }
}
