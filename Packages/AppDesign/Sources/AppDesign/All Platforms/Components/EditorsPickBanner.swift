import SwiftUI

public struct EditorsPickBanner: View {

    private let category: String
    private let headline: String
    private let description: String
    private let appIconSystemName: String
    private let appIconBackground: Color
    private let appIconForeground: Color
    private let appName: String
    private let appAuthor: String
    private let openAction: () -> Void

    private let primaryText: Color = .white
    private let secondaryText: Color = .white.opacity(0.75)
    private let tertiaryText: Color = .white.opacity(0.5)

    public init(
        category: String = "Editor's Pick",
        headline: String,
        description: String,
        appIconSystemName: String,
        appIconBackground: Color = .white,
        appIconForeground: Color = Color(white: 0.3),
        appName: String,
        appAuthor: String,
        openAction: @escaping () -> Void
    ) {
        self.category = category
        self.headline = headline
        self.description = description
        self.appIconSystemName = appIconSystemName
        self.appIconBackground = appIconBackground
        self.appIconForeground = appIconForeground
        self.appName = appName
        self.appAuthor = appAuthor
        self.openAction = openAction
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(category.uppercased())
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(tertiaryText)

            Text(headline)
                .lineLimit(2)
                .font(.system(size: 40, weight: .bold))
                .minimumScaleFactor(0.5)
                .foregroundStyle(primaryText)
                .frame(maxWidth: 370)

            Spacer().frame(height: 16)

            Text(description)
                .lineLimit(3)
                .font(.body)
                .foregroundStyle(secondaryText)
                .lineSpacing(4)
                .frame(maxWidth: 370)

            Spacer().frame(height: 32)

            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(appIconBackground)
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: appIconSystemName)
                            .font(.system(size: 30, weight: .regular))
                            .foregroundStyle(appIconForeground)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(appName)
                        .font(.headline)
                        .foregroundStyle(primaryText)
                    Text(appAuthor)
                        .font(.subheadline)
                        .foregroundStyle(tertiaryText)
                }

                Spacer(minLength: 12)

                Button(action: openAction) {
                    Text("Open")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.8), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(28)
        .frame(minWidth: 300)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.22, green: 0.26, blue: 0.36),
                            Color(red: 0.10, green: 0.12, blue: 0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

#Preview {
    EditorsPickBanner(
        headline: "Docs 4.1 makes the wiki disappear.",
        description: "Offline-first, keyboard-native, and now meaningfully faster on large spaces. The full company knowledge base in a Mac app that gets out of your way.",
        appIconSystemName: "doc.text.fill",
        appName: "Docs",
        appAuthor: "by Platform",
        openAction: {}
    )
    .padding()
    .frame(width: 600)
}
