import SwiftUI

public struct AppDetailsHeader: View {

    private let title: String
    private let subtitle: String?
    private let description: String?

    public init(_ title: String, subtitle: String? = nil, description: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.description = description
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let subtitle {
                Text(subtitle.uppercased())
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.tertiary)
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
    }
}
