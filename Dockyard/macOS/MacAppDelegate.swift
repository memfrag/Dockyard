//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI

class MacAppDelegate: NSObject, NSApplicationDelegate {

    /// Minimum interval between focus-triggered catalog refreshes.
    private let focusRefreshCooldown: TimeInterval = 15 * 60

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    /// Fires on launch and every time the app returns to the foreground.
    /// `refreshIfStale` no-ops if the cooldown hasn't elapsed, so this is safe to call often.
    func applicationDidBecomeActive(_ notification: Notification) {
        Task { @MainActor in
            await AppEnvironment.default.dockyardEngine
                .refreshIfStale(minInterval: focusRefreshCooldown)
        }
    }
}
