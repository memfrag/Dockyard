import SwiftUI

public struct ChannelBadge: View {

    private let channel: String

    public init(_ channel: String) {
        self.channel = channel
    }

    public var body: some View {
        Text(channel.uppercased())
            .font(.footnote)
            .foregroundStyle(Color.Badge.channelText)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background {
                RoundedRectangle(cornerRadius: 4)
                    .foregroundStyle(Color.Badge.channelBackground)
            }
    }
}

#Preview {
    ChannelBadge("Beta")
        .padding()
}
