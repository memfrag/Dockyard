import SwiftUI

public struct AppDetailsSectionHeader: View {

    private let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title.uppercased())
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.tertiary)
    }
}

#Preview {
    VStack(alignment: .leading) {
        AppDetailsSectionHeader("What's New")
        .padding()
    }
}
