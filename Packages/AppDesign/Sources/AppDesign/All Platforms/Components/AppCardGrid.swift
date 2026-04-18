import SwiftUI

public struct AppCardMenuItem: Identifiable {
    public let id: UUID
    public let title: String
    public let systemImage: String?
    public let isDestructive: Bool
    public let action: () -> Void

    public init(
        id: UUID = UUID(),
        title: String,
        systemImage: String? = nil,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.isDestructive = isDestructive
        self.action = action
    }
}

public struct AppCardItem: Identifiable {

    public let id: String
    public let icon: AppIconSource
    public let category: String
    public let title: String
    public let description: String
    public let actionTitle: String
    public let actionEnabled: Bool
    public let progress: Double?
    public let action: () -> Void
    public let menuItems: [AppCardMenuItem]

    public init(
        id: String = UUID().uuidString,
        icon: AppIconSource,
        category: String,
        title: String,
        description: String,
        actionTitle: String = "Open",
        actionEnabled: Bool = true,
        progress: Double? = nil,
        action: @escaping () -> Void = {},
        menuItems: [AppCardMenuItem] = []
    ) {
        self.id = id
        self.icon = icon
        self.category = category
        self.title = title
        self.description = description
        self.actionTitle = actionTitle
        self.actionEnabled = actionEnabled
        self.progress = progress
        self.action = action
        self.menuItems = menuItems
    }

    /// Convenience initializer for SF-symbol icons with the default "Open" label.
    public init(
        id: String = UUID().uuidString,
        iconSystemName: String,
        iconBackground: Color,
        category: String,
        title: String,
        description: String,
        openAction: @escaping () -> Void = {}
    ) {
        self.init(
            id: id,
            icon: .symbol(name: iconSystemName, background: iconBackground),
            category: category,
            title: title,
            description: description,
            actionTitle: "Open",
            action: openAction
        )
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
                    icon: item.icon,
                    category: item.category,
                    title: item.title,
                    description: item.description,
                    actionTitle: item.actionTitle,
                    actionEnabled: item.actionEnabled,
                    progress: item.progress,
                    menuItems: item.menuItems,
                    action: item.action
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
