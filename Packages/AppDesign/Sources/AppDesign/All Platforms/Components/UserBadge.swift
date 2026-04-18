import SwiftUI

public struct UserBadge: View {

    @Environment(\.colorScheme) var colorScheme

    private let name = NSFullUserName()

    private var initials: String {
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
    }

    public init() {
        //
    }

    public var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.accentColor)
                .overlay(
                    Text(initials)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white)
                )
                .frame(width: 26, height: 26)

            Text(name)

            Spacer()
        }
    }
}

#Preview {
    UserBadge()
        .frame(width: 180)
        .padding()
}
