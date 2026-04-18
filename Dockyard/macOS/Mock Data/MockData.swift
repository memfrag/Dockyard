//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import AppDesign

struct MockData {
    static let featuredApps: [AppCardItem] = [
        AppCardItem(
            iconSystemName: "person.fill",
            iconBackground: .blue,
            category: "People",
            title: "Directory",
            description: "Find people by team, role, or name"
        ),
        AppCardItem(
            iconSystemName: "video.fill",
            iconBackground: .red,
            category: "Productivity",
            title: "Meet",
            description: "One-click video calls with anyone"
        ),
        AppCardItem(
            iconSystemName: "bubble.left.and.bubble.right.fill",
            iconBackground: .purple,
            category: "Productivity",
            title: "Chat",
            description: "Team channels, DMs, and threads"
        ),
        AppCardItem(
            iconSystemName: "calendar",
            iconBackground: .orange,
            category: "Productivity",
            title: "Schedule",
            description: "Your week at a glance"
        ),
        AppCardItem(
            iconSystemName: "doc.text.fill",
            iconBackground: .teal,
            category: "Writing",
            title: "Notes",
            description: "Capture ideas, link anything"
        ),
        AppCardItem(
            iconSystemName: "chart.bar.fill",
            iconBackground: .green,
            category: "Analytics",
            title: "Pulse",
            description: "Live dashboards and alerts"
        )
    ]
}
