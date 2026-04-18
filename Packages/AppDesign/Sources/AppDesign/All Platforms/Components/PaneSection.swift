import SwiftUI

public struct PaneSection<Content: View>: View {

    private let title: String
    private let subtitle: String?
    private let content: () -> Content

    public init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PaneSectionHeader(title, subtitle: subtitle)
            content()
        }
    }
}

#Preview {
    PaneSection(
        "For your team",
        subtitle: "Picked for you based on what members of your team use most"
    ) {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.2))
            .frame(height: 120)
    }
    .padding()
    .frame(width: 600)
}
