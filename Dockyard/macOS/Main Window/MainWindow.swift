//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftUIToolbox

struct MainWindow: Scene {
    
    var body: some Scene {

        WindowGroup {
            Sidebar()
                .frame(minWidth: 400, minHeight: 400)
                .background(AlwaysOnTop())
                .appEnvironment(.default)
        }
        .commands {
            AboutCommand()
            SidebarCommands()
            ExportCommands()
            AlwaysOnTopCommand()
            HelpCommands()
            
            /// Add a menu with custom commands
            MyCommands()
            
            // Remove the "New Window" option from the File menu.
            CommandGroup(replacing: .newItem, addition: { })
        }
        
    }
}
