import SwiftUI

public struct EditorsPickBanner: View {

    public static let defaultGradient: [Color] = [
        Color(red: 0.22, green: 0.26, blue: 0.36),
        Color(red: 0.10, green: 0.12, blue: 0.20)
    ]

    private let category: String
    private let headline: String
    private let description: String
    private let icon: AppIconSource
    private let appName: String
    private let appAuthor: String
    private let gradient: [Color]
    private let actionTitle: String
    private let actionEnabled: Bool
    private let progress: Double?
    private let action: () -> Void
    private let onOpenDetails: (() -> Void)?

    private let primaryText: Color = .white
    private let secondaryText: Color = .white.opacity(0.75)
    private let tertiaryText: Color = .white.opacity(0.5)

    public init(
        category: String = "Editor's Pick",
        headline: String,
        description: String,
        icon: AppIconSource,
        appName: String,
        appAuthor: String,
        gradient: [Color] = EditorsPickBanner.defaultGradient,
        actionTitle: String = "Open",
        actionEnabled: Bool = true,
        progress: Double? = nil,
        onOpenDetails: (() -> Void)? = nil,
        action: @escaping () -> Void
    ) {
        self.category = category
        self.headline = headline
        self.description = description
        self.icon = icon
        self.appName = appName
        self.appAuthor = appAuthor
        self.gradient = gradient.isEmpty ? EditorsPickBanner.defaultGradient : gradient
        self.actionTitle = actionTitle
        self.actionEnabled = actionEnabled
        self.progress = progress
        self.onOpenDetails = onOpenDetails
        self.action = action
    }

    /// Convenience initializer for SF-symbol icons with the default gradient.
    public init(
        category: String = "Editor's Pick",
        headline: String,
        description: String,
        appIconSystemName: String,
        appIconBackground: Color = .white,
        appIconForeground: Color = Color(white: 0.3),
        appName: String,
        appAuthor: String,
        actionTitle: String = "Open",
        actionEnabled: Bool = true,
        progress: Double? = nil,
        onOpenDetails: (() -> Void)? = nil,
        action: @escaping () -> Void
    ) {
        self.init(
            category: category,
            headline: headline,
            description: description,
            icon: .symbol(
                name: appIconSystemName,
                background: appIconBackground,
                foreground: appIconForeground
            ),
            appName: appName,
            appAuthor: appAuthor,
            gradient: EditorsPickBanner.defaultGradient,
            actionTitle: actionTitle,
            actionEnabled: actionEnabled,
            progress: progress,
            onOpenDetails: onOpenDetails,
            action: action
        )
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
                AppIcon(source: icon, size: 64, cornerRadius: 14)

                VStack(alignment: .leading, spacing: 2) {
                    Text(appName)
                        .font(.headline)
                        .foregroundStyle(primaryText)
                    Text(appAuthor)
                        .font(.subheadline)
                        .foregroundStyle(tertiaryText)
                }

                Spacer(minLength: 12)

                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(actionEnabled ? .black : Color.black.opacity(0.5))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(actionEnabled ? 0.85 : 0.55), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!actionEnabled)
            }

            if let progress {
                Spacer().frame(height: 10)
                ProgressView(value: progress.clamped(to: 0...1))
                    .progressViewStyle(.linear)
                    .tint(.white)
            }
        }
        .padding(28)
        .frame(minWidth: 300)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            onOpenDetails?()
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

#Preview {
    VStack(spacing: 16) {
        EditorsPickBanner(
            headline: "Docs 4.1 makes the wiki disappear.",
            description: "Offline-first, keyboard-native, and now meaningfully faster on large spaces.",
            appIconSystemName: "doc.text.fill",
            appName: "Docs",
            appAuthor: "by Platform",
            action: {}
        )
        EditorsPickBanner(
            headline: "Deploy is downloading.",
            description: "Progress and a disabled button mirror the grid card behavior.",
            appIconSystemName: "airplane",
            appIconBackground: .black,
            appIconForeground: .white,
            appName: "Deploy",
            appAuthor: "by Platform",
            actionTitle: "42%",
            actionEnabled: false,
            progress: 0.42,
            action: {}
        )
    }
    .padding()
    .frame(width: 600)
}
