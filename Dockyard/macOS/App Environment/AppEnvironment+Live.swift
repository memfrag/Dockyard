//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation
import AppRouting
import DockyardEngine
import URLToolbox

extension AppEnvironment {

    // MARK: - Live AppEnvironment

    /// The production catalog manifest URL.
    ///
    /// - TODO: Replace with the real hosted manifest URL when publishing.
    ///
    private static let manifestURL = URL(vouchedFor: "https://raw.githubusercontent.com/memfrag/DockyardManifest/main/manifest.json")

    /// The production editorial content URL, published alongside the manifest.
    private static let editorialURL = URL(vouchedFor: "https://raw.githubusercontent.com/memfrag/DockyardManifest/main/editorial.json")

    /// Builds a live environment configured for production behavior.
    ///
    /// Intended only for ``#Preview`` usage and tests where an explicit instance is required.
    /// Most code should access ``shared`` instead.
    ///
    /// - Returns: A new ``AppEnvironment`` instance with live dependencies.
    ///
    internal static func live() -> AppEnvironment {
        AppEnvironment(
            appSettings: AppSettings(),
            dockyardEngine: DockyardEngine(manifestURL: manifestURL, editorialURL: editorialURL),
            authService: AuthService.mock(),
            engineeringMode: EngineeringMode.shared
        )
    }
}
