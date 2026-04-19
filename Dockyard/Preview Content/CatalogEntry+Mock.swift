//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation
import DockyardEngine
import URLToolbox

extension CatalogEntry {

    struct Mock {
        static let repoRanger = CatalogEntry(
            id: "io.apparata.RepoRanger",
            displayName: "RepoRanger",
            category: "Development",
            summary: "Keep track of your app projects.",
            iconURL: URL(vouchedFor: "https://raw.githubusercontent.com/memfrag/DockyardManifest/main/app-icons/RepoRangerAppIcon.png"),
            version: "1.0.0",
            dmgURL: URL(vouchedFor: "https://github.com/apparata/RepoRanger/releases/download/v1.0.0/RepoRanger-v1.0.0.dmg"),
            dmgSize: 2_345_678
        )
    }
}
