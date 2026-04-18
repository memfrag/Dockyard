//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftUIToolbox
import AttributionsUI
import AppDesign

@main
struct MacApp: App {

    // swiftlint:disable:next weak_delegate
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) var appDelegate

    init() {
        AppDesign.apply()
        Task { @MainActor in
            try? await AppEnvironment.default.dockyardEngine.refreshCatalog()
        }
    }
    
    var body: some Scene {
        MainWindow()
        MenuBarWindow()
        SettingsWindow()
        AboutWindow(developedBy: "Apparata AB",
                    attributionsWindowID: AttributionsWindow.windowID)
        AttributionsWindow([
            ("CGMath", .bsd0Clause(year: "2025", holder: "Apparata AB")),
            ("MathKit", .bsd0Clause(year: "2025", holder: "Apparata AB"))
        ], header: "The following software may be included in this product.")
        HelpWindow()
    }
}
