import SwiftUI

public struct LargeAppCard: View {

    @Environment(\.colorScheme) private var colorScheme

    private let icon: AppIconSource
    private let category: String
    private let title: String
    private let description: String
    private let channel: String?
    private let onOpenDetails: (() -> Void)?

    public init(
        icon: AppIconSource,
        category: String,
        title: String,
        description: String,
        channel: String?,
        onOpenDetails: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.category = category
        self.title = title
        self.description = description
        self.channel = channel
        self.onOpenDetails = onOpenDetails
    }

    /// Convenience initializer for SF-symbol icons.
    public init(
        iconSystemName: String,
        iconBackground: Color,
        iconForeground: Color = .white,
        category: String,
        title: String,
        description: String,
        channel: String?,
        onOpenDetails: (() -> Void)? = nil
    ) {
        self.init(
            icon: .symbol(
                name: iconSystemName,
                background: iconBackground,
                foreground: iconForeground
            ),
            category: category,
            title: title,
            description: description,
            channel: channel,
            onOpenDetails: onOpenDetails
        )
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 18) {
            AppIcon(source: icon, size: 72, cornerRadius: 18)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(category.uppercased())
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                    if let channel {
                        ChannelBadge(channel)
                    }
                }
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background {
            let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
            if colorScheme == .dark {
                shape.fill(Color.gray.opacity(0.15))
            } else {
                shape.strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            onOpenDetails?()
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        LargeAppCard(
            iconSystemName: "airplane",
            iconBackground: .black,
            category: "New to Hub",
            title: "Deploy",
            description: "A thin client over the deploy pipeline. Now in beta.",
            channel: nil
        )
        LargeAppCard(
            iconSystemName: "video.fill",
            iconBackground: .red,
            category: "Updated",
            title: "Meet 1.3",
            description: "Picture-in-picture when you switch windows.",
            channel: "Beta"
        )
    }
    .padding()
    .frame(width: 420, height: 420)
}
