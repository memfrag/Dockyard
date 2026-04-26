import SwiftUI

/// Shown on a card when the catalog version Dockyard installed disagrees with the
/// `CFBundleShortVersionString` in the bundle that landed on disk — i.e., the
/// publisher cut a release without bumping the bundle's plist version.
public struct VersionMismatchBadge: View {

    public init() {}

    public var body: some View {
        Label("Version mismatch", systemImage: "exclamationmark.triangle.fill")
            .labelStyle(.iconOnly)
            .font(.footnote)
            .foregroundStyle(.orange)
            .help("The installed bundle reports a different version than the catalog. The publisher likely shipped a DMG without bumping CFBundleShortVersionString.")
            .accessibilityLabel("Version mismatch")
    }
}

#Preview {
    VersionMismatchBadge()
        .padding()
}
