import SwiftUI

public struct AppCard: View {

    @Environment(\.colorScheme) private var colorScheme

    private let iconSystemName: String
    private let iconBackground: Color
    private let category: String
    private let title: String
    private let description: String
    private let openAction: () -> Void

    public init(
        iconSystemName: String,
        iconBackground: Color,
        category: String,
        title: String,
        description: String,
        openAction: @escaping () -> Void
    ) {
        self.iconSystemName = iconSystemName
        self.iconBackground = iconBackground
        self.category = category
        self.title = title
        self.description = description
        self.openAction = openAction
    }

    public var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(iconBackground)
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: iconSystemName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }

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

            Button(action: openAction) {
                Text("Open")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Color.gray.opacity(0.25), in: Capsule())
            }
            .buttonStyle(.plain)
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
            iconSystemName: "video.fill",
            iconBackground: .red,
            category: "Productivity",
            title: "Meet",
            description: "One-click video calls with anyone",
            openAction: {}
        )
        AppCard(
            iconSystemName: "bubble.left.and.bubble.right.fill",
            iconBackground: .purple,
            category: "Productivity",
            title: "Chat",
            description: "Team channels, DMs, and threads",
            openAction: {}
        )
    }
    .padding()
    .frame(width: 640)
}
