//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftUIToolbox
import Sparkle

struct MainWindow: Scene {

    let updater: SPUUpdater

    @AppStorage("appearancePreference") private var appearance: AppearancePreference = .system

    var body: some Scene {

        WindowGroup {
            Sidebar()
                .frame(minWidth: 1200, minHeight: 580)
                .background(AlwaysOnTop())
                .appEnvironment(.default)
                .preferredColorScheme(appearance.colorScheme)
        }
        .commands {
            AboutCommand()
            CheckForUpdatesCommand(updater: updater)
            // Replaces the default "New Window" with Refresh Catalog, keeping
            // the File menu populated.
            RefreshCatalogCommand()
            SidebarCommands()
            AlwaysOnTopCommand()
            HelpCommands()
        }

    }
}
