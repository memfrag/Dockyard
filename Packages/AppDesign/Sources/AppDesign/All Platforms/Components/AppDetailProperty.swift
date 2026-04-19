import SwiftUI

public struct AppDetailProperty: View {

    private let title: String
    private let value: String

    public init(_ title: String, value: String) {
        self.title = title
        self.value = value
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .fontWeight(.bold)
            Text(title.uppercased())
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    AppDetailProperty("Version", value: "1.2.0")
        .padding()
}
