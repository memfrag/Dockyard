//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftUIToolbox
import AppDesign

struct TodayPane: View {

    private let featuredApps: [FeaturedApp] = [
        FeaturedApp(
            iconSystemName: "person.fill",
            iconBackground: .blue,
            category: "People",
            title: "Directory",
            description: "Find people by team, role, or name"
        ),
        FeaturedApp(
            iconSystemName: "video.fill",
            iconBackground: .red,
            category: "Productivity",
            title: "Meet",
            description: "One-click video calls with anyone"
        ),
        FeaturedApp(
            iconSystemName: "bubble.left.and.bubble.right.fill",
            iconBackground: .purple,
            category: "Productivity",
            title: "Chat",
            description: "Team channels, DMs, and threads"
        ),
        FeaturedApp(
            iconSystemName: "calendar",
            iconBackground: .orange,
            category: "Productivity",
            title: "Schedule",
            description: "Your week at a glance"
        ),
        FeaturedApp(
            iconSystemName: "doc.text.fill",
            iconBackground: .teal,
            category: "Writing",
            title: "Notes",
            description: "Capture ideas, link anything"
        ),
        FeaturedApp(
            iconSystemName: "chart.bar.fill",
            iconBackground: .green,
            category: "Analytics",
            title: "Pulse",
            description: "Live dashboards and alerts"
        )
    ]

    private let cardColumns = [GridItem(.adaptive(minimum: 250), spacing: 16)]

    var body: some View {
        Pane {
            NavigationStack {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 20) {
                        PaneHeader(
                            "On the shelf this week",
                            subtitle: "Today · \(Date().weekdayDayMonth())"
                        )

                        HStack(alignment: .top, spacing: 16) {
                            EditorsPickBanner(
                                headline: "Docs 4.1 makes the wiki disappear.",
                                description: "Offline-first, keyboard-native, and now meaningfully faster on large spaces. The full company knowledge base in a Mac app that gets out of your way.",
                                appIconSystemName: "doc.text.fill",
                                appName: "Docs",
                                appAuthor: "by Platform",
                                openAction: {}
                            )

                            VStack(spacing: 16) {
                                LargeAppCard(
                                    iconSystemName: "airplane",
                                    iconBackground: .black,
                                    category: "New to Hub",
                                    title: "Deploy",
                                    description: "A thin client over the deploy pipeline. Now in beta."
                                )
                                .frame(maxHeight: .infinity)

                                LargeAppCard(
                                    iconSystemName: "video.fill",
                                    iconBackground: .red,
                                    category: "Updated",
                                    title: "Meet 1.3",
                                    description: "Picture-in-picture when you switch windows."
                                )
                                .frame(maxHeight: .infinity)
                            }
                            .frame(width: 380)
                        }
                        .fixedSize(horizontal: false, vertical: true)

                        PaneSectionHeader(
                            "For your team",
                            subtitle: "Picked for you based on what members of your team use most"
                        )

                        LazyVGrid(columns: cardColumns, alignment: .leading, spacing: 16) {
                            ForEach(featuredApps) { app in
                                AppCard(
                                    iconSystemName: app.iconSystemName,
                                    iconBackground: app.iconBackground,
                                    category: app.category,
                                    title: app.title,
                                    description: app.description,
                                    openAction: {}
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(32)
                }
            }
        }
        .navigationTitle("Today")
    }
}

private struct FeaturedApp: Identifiable {
    let id = UUID()
    let iconSystemName: String
    let iconBackground: Color
    let category: String
    let title: String
    let description: String
}

#Preview {
    TodayPane()
}
