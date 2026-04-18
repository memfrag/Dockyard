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
        VStack(alignment: .leading, spacing: 16) {
            Text(category.uppercased())
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text(headline)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 24)

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
                        .foregroundStyle(.primary)
                    Text(appAuthor)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Button(action: openAction) {
                    Text("Open")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.3), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.12, blue: 0.20),
                            Color(red: 0.22, green: 0.26, blue: 0.36)
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
    .frame(width: 900, height: 420)
}
