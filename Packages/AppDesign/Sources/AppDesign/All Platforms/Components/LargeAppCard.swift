import SwiftUI

public struct LargeAppCard: View {

    @Environment(\.colorScheme) private var colorScheme

    private let iconSystemName: String
    private let iconBackground: Color
    private let iconForeground: Color
    private let category: String
    private let title: String
    private let description: String

    public init(
        iconSystemName: String,
        iconBackground: Color,
        iconForeground: Color = .white,
        category: String,
        title: String,
        description: String
    ) {
        self.iconSystemName = iconSystemName
        self.iconBackground = iconBackground
        self.iconForeground = iconForeground
        self.category = category
        self.title = title
        self.description = description
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 18) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(iconBackground)
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: iconSystemName)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(iconForeground)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(category.uppercased())
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
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
    }
}

#Preview {
    VStack(spacing: 16) {
        LargeAppCard(
            iconSystemName: "airplane",
            iconBackground: .black,
            category: "New to Hub",
            title: "Deploy",
            description: "A thin client over the deploy pipeline. Now in beta."
        )
        LargeAppCard(
            iconSystemName: "video.fill",
            iconBackground: .red,
            category: "Updated",
            title: "Meet 1.3",
            description: "Picture-in-picture when you switch windows."
        )
    }
    .padding()
    .frame(width: 420, height: 420)
}
