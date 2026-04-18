import SwiftUI

public struct AppCard: View {

    @Environment(\.colorScheme) private var colorScheme

    private let icon: AppIconSource
    private let category: String
    private let title: String
    private let description: String
    private let actionTitle: String
    private let actionEnabled: Bool
    private let progress: Double?
    private let menuItems: [AppCardMenuItem]
    private let action: () -> Void

    public init(
        icon: AppIconSource,
        category: String,
        title: String,
        description: String,
        actionTitle: String = "Open",
        actionEnabled: Bool = true,
        progress: Double? = nil,
        menuItems: [AppCardMenuItem] = [],
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.category = category
        self.title = title
        self.description = description
        self.actionTitle = actionTitle
        self.actionEnabled = actionEnabled
        self.progress = progress
        self.menuItems = menuItems
        self.action = action
    }

    /// Convenience initializer for SF-symbol icons with the default "Open" label.
    public init(
        iconSystemName: String,
        iconBackground: Color,
        category: String,
        title: String,
        description: String,
        openAction: @escaping () -> Void
    ) {
        self.init(
            icon: .symbol(name: iconSystemName, background: iconBackground),
            category: category,
            title: title,
            description: description,
            actionTitle: "Open",
            action: openAction
        )
    }

    public var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                AppIcon(source: icon, size: 48, cornerRadius: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.uppercased())
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(actionEnabled ? .primary : .secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(Color.gray.opacity(0.25), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!actionEnabled)
            }

            if let progress {
                ProgressView(value: progress.clamped(to: 0...1))
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
            }
        }
        .padding(12)
        .background {
            let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
            if colorScheme == .dark {
                shape.fill(Color.gray.opacity(0.15))
            } else {
                shape.strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
            }
        }
        .contextMenu {
            if !menuItems.isEmpty {
                ForEach(menuItems) { item in
                    Button(role: item.isDestructive ? .destructive : nil, action: item.action) {
                        if let systemImage = item.systemImage {
                            Label(item.title, systemImage: systemImage)
                        } else {
                            Text(item.title)
                        }
                    }
                }
            }
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

#Preview {
    VStack(spacing: 12) {
        AppCard(
            iconSystemName: "person.fill",
            iconBackground: .blue,
            category: "People",
            title: "Directory",
            description: "Find people by team, role, or name",
            openAction: {}
        )
        AppCard(
            icon: .symbol(name: "arrow.down.circle.fill", background: .indigo),
            category: "Productivity",
            title: "Meet",
            description: "One-click video calls with anyone",
            actionTitle: "Install",
            action: {}
        )
        AppCard(
            icon: .symbol(name: "bubble.left.and.bubble.right.fill", background: .purple),
            category: "Productivity",
            title: "Chat",
            description: "Team channels, DMs, and threads",
            actionTitle: "38%",
            actionEnabled: false,
            progress: 0.38,
            action: {}
        )
        AppCard(
            icon: .symbol(name: "cloud.fill", background: .cyan),
            category: "Utilities",
            title: "Sync",
            description: "Keeps your stuff in step",
            actionTitle: "Queued",
            actionEnabled: false,
            action: {}
        )
    }
    .padding()
    .frame(width: 640)
}
