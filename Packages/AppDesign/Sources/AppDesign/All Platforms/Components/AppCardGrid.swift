import SwiftUI

public struct AppCardItem: Identifiable {

    public let id: UUID
    public let iconSystemName: String
    public let iconBackground: Color
    public let category: String
    public let title: String
    public let description: String
    public let openAction: () -> Void

    public init(
        id: UUID = UUID(),
        iconSystemName: String,
        iconBackground: Color,
        category: String,
        title: String,
        description: String,
        openAction: @escaping () -> Void = {}
    ) {
        self.id = id
        self.iconSystemName = iconSystemName
        self.iconBackground = iconBackground
        self.category = category
        self.title = title
        self.description = description
        self.openAction = openAction
    }
}

public struct AppCardGrid: View {

    private let items: [AppCardItem]
    private let minimumCardWidth: CGFloat
    private let spacing: CGFloat

    public init(
        items: [AppCardItem],
        minimumCardWidth: CGFloat = 250,
        spacing: CGFloat = 16
    ) {
        self.items = items
        self.minimumCardWidth = minimumCardWidth
        self.spacing = spacing
    }

    public var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: minimumCardWidth), spacing: spacing)],
            alignment: .leading,
            spacing: spacing
        ) {
            ForEach(items) { item in
                AppCard(
                    iconSystemName: item.iconSystemName,
                    iconBackground: item.iconBackground,
                    category: item.category,
                    title: item.title,
                    description: item.description,
                    openAction: item.openAction
                )
            }
        }
    }
}

#Preview {
    AppCardGrid(items: [
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
        )
    ])
    .padding()
    .frame(width: 900)
}
