//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation

enum SidebarPane {
    
    // MARK: Dockyard Section

    case today
    case discover
    case installed

    // MARK: Categories Section

    case design
    case development
    case entertainment
    case finance
    case productivity
}

// MARK: - Protocol Conformances

extension SidebarPane: Equatable, Identifiable {
    var id: Self { self }
}
