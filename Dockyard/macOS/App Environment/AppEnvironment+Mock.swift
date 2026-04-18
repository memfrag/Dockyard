//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation
import AppRouting
import DockyardEngine
import URLToolbox

extension AppEnvironment {

    // MARK: - Mock AppEnvironment

    #if DEBUG
    /// Builds a mock environment configured for development and preview usage.
    ///
    /// Available only in `DEBUG` builds.
    ///
    /// - Returns: A new ``AppEnvironment`` instance with mocked dependencies.
    ///
    internal static func mock() -> AppEnvironment {
        let manifestURL = URL(vouchedFor: "https://example.com/dockyard/manifest.json")
        return AppEnvironment(
            appSettings: AppSettings.mock(),
            dockyardEngine: DockyardEngine(manifestURL: manifestURL),
            authService: AuthService.mock(),
            engineeringMode: EngineeringMode.shared
        )
    }
    #endif
}
