import SwiftUI

public struct PaneHeader: View {

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
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    VStack {
        PaneHeader("On the shelf this week")
            .padding()
        PaneHeader(
            "On the shelf this week",
            subtitle: "Today · Friday, 17 April",
        )
        .padding()
        PaneHeader(
            "On the shelf this week",
            subtitle: "Today · Friday, 17 April",
            description: "Some text about the title and stuff."
        )
        .padding()
    }
}
