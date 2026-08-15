//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI

extension Color {

    public struct Badge {
        /// Blue. The neutral badge — used for the web-app marker.
        public static let background = Color(.Theme.Color.Badge.background)
        public static let text = Color(.Theme.Color.Badge.text)

        /// Amber. Reserved for the release-channel badge, so "Beta" reads as a
        /// caveat rather than as another descriptive label. Matches the amber
        /// the web catalog already uses for the same badge.
        public static let channelBackground = Color(.Theme.Color.Badge.channelBackground)
        public static let channelText = Color(.Theme.Color.Badge.channelText)
    }

    public struct Text {
        public static let primary = Color.primary
        public static let secondary = Color.secondary
    }
}
