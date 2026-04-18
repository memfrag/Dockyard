//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI

enum AppearancePreference: String {
    case system
    case light
    case dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var next: AppearancePreference {
        switch self {
        case .system: .light
        case .light: .dark
        case .dark: .system
        }
    }

    var symbolName: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    var label: String {
        switch self {
        case .system: "Appearance: System"
        case .light: "Appearance: Light"
        case .dark: "Appearance: Dark"
        }
    }
}
