import SwiftUI

public struct PaneSectionHeader: View {

    private let title: String
    private let subtitle: String?

    public init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            if let subtitle {
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        PaneSectionHeader("For your team")
            .padding()
        PaneSectionHeader(
            "For your team",
            subtitle: "Picked for you based on what members of your team use most"
        )
        .padding()
    }
}
