import SwiftUI

/// Marks a catalog entry that opens in the browser rather than being installed,
/// so it's clear before tapping that nothing lands on disk.
public struct WebAppBadge: View {

    public init() {}

    public var body: some View {
        // Deliberately built like `ChannelBadge` — same type, same metrics — so
        // "WEB" and "BETA" read as one family when a card carries both. It must
        // never wrap or compress: in a narrow card the row would otherwise
        // squeeze it and break the word across two lines.
        Text("Web".uppercased())
            .font(.footnote)
            .foregroundStyle(Color.Badge.text)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background {
                RoundedRectangle(cornerRadius: 4)
                    .foregroundStyle(Color.Badge.background)
            }
    }
}

#Preview {
    HStack {
        WebAppBadge()
        ChannelBadge("Beta")
    }
    .padding()
}
