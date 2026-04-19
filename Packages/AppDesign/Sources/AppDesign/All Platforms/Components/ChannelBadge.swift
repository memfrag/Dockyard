import SwiftUI

public struct ChannelBadge: View {

    private let channel: String

    public init(_ channel: String) {
        self.channel = channel
    }

    public var body: some View {
        Text(channel.uppercased())
            .font(.footnote)
            .foregroundStyle(Color.Badge.text)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background {
                RoundedRectangle(cornerRadius: 4)
                    .foregroundStyle(Color.Badge.background)
            }
    }
}

#Preview {
    ChannelBadge("Beta")
        .padding()
}
