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
            description: "Find people by team, role, or name",
            channel: nil
        ),
        AppCardItem(
            iconSystemName: "video.fill",
            iconBackground: .red,
            category: "Productivity",
            title: "Meet",
            description: "One-click video calls with anyone",
            channel: nil
        ),
        AppCardItem(
            iconSystemName: "bubble.left.and.bubble.right.fill",
            iconBackground: .purple,
            category: "Productivity",
            title: "Chat",
            description: "Team channels, DMs, and threads",
            channel: nil
        ),
        AppCardItem(
            iconSystemName: "calendar",
            iconBackground: .orange,
            category: "Productivity",
            title: "Schedule",
            description: "Your week at a glance",
            channel: nil
        ),
        AppCardItem(
            iconSystemName: "doc.text.fill",
            iconBackground: .teal,
            category: "Writing",
            title: "Notes",
            description: "Capture ideas, link anything",
            channel: nil
        ),
        AppCardItem(
            iconSystemName: "chart.bar.fill",
            iconBackground: .green,
            category: "Analytics",
            title: "Pulse",
            description: "Live dashboards and alerts",
            channel: nil
        )
    ]
}
