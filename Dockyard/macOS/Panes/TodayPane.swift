//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftUIToolbox
import AppDesign

struct TodayPane: View {

    var body: some View {
        Pane {
            NavigationStack {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        PaneHeader(
                            "On the shelf this week",
                            subtitle: "Today · \(Date().weekdayDayMonth())"
                        )
                        .padding(.bottom, 16)

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
                                    category: "New to Dockyard",
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
                        .padding(.bottom, 32)

                        PaneSection(
                            "For your team",
                            subtitle: "Picked for you based on what members of your team use most"
                        ) {
                            AppCardGrid(items: MockData.featuredApps)
                        }
                        .padding(.bottom, 32)

                        PaneSection("Recently updated") {
                            AppCardGrid(items: MockData.featuredApps)
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

#Preview {
    TodayPane()
}
