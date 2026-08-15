import SwiftUI

public struct AppDetailsHeader: View {

    private let title: String
    private let subtitle: String?
    private let description: String?
    private let channel: String?
    private let isWebApp: Bool

    public init(
        _ title: String,
        subtitle: String? = nil,
        description: String? = nil,
        channel: String? = nil,
        isWebApp: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.channel = channel
        self.isWebApp = isWebApp
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let subtitle {
                HStack(spacing: 8) {
                    Text(subtitle.uppercased())
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.tertiary)
                    if isWebApp {
                        WebAppBadge()
                    }
                    if let channel {
                        ChannelBadge(channel)
                    }
                }
            }
            Text(title)
                .font(.largeTitle)
                .bold()
                .foregroundStyle(.primary)
            if let description {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        AppDetailsHeader("RepoRanger")
            .padding()
        AppDetailsHeader(
            "RepoRanger",
            subtitle: "Development",
        )
        .padding()
        AppDetailsHeader(
            "RepoRanger",
            subtitle: "Development",
            description: "Keep track of your app projects."
        )
        .padding()
        AppDetailsHeader(
            "RepoRanger",
            subtitle: "Development",
            description: "Keep track of your app projects.",
            channel: "Beta"
        )
        .padding()
    }
}
