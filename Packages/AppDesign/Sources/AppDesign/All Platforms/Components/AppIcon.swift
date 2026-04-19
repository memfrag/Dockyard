import SwiftUI

public struct AppIcon: View {

    @Environment(\.colorScheme) private var colorScheme

    private let source: AppIconSource
    private let size: CGFloat
    private let cornerRadius: CGFloat

    public init(source: AppIconSource, size: CGFloat, cornerRadius: CGFloat) {
        self.source = source
        self.size = size
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        iconBody
            .overlay(lightModeBorder)
    }

    @ViewBuilder
    private var iconBody: some View {
        switch source {
        case .symbol(let name, let background, let foreground):
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(background)
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: name)
                        .font(.system(size: size * 0.47, weight: .semibold))
                        .foregroundStyle(foreground)
                }
        case .file(let url):
            fileIcon(url)
        }
    }

    @ViewBuilder
    private var lightModeBorder: some View {
        if colorScheme == .light {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.black.opacity(0.1), lineWidth: 0.5)
                .frame(width: size, height: size)
        }
    }

    @ViewBuilder
    private func fileIcon(_ url: URL) -> some View {
        if let image = PlatformImage.load(from: url) {
            #if canImport(AppKit)
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            #elseif canImport(UIKit)
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            #endif
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.gray.opacity(0.2))
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: "questionmark.app")
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
        }
    }
}

#if canImport(AppKit)
import AppKit
private typealias PlatformImage = NSImage

private extension NSImage {
    static func load(from url: URL) -> NSImage? {
        NSImage(contentsOf: url)
    }
}
#elseif canImport(UIKit)
import UIKit
private typealias PlatformImage = UIImage

private extension UIImage {
    static func load(from url: URL) -> UIImage? {
        UIImage(contentsOfFile: url.path)
    }
}
#endif

#Preview {
    VStack(spacing: 16) {
        AppIcon(
            source: .symbol(name: "sparkles", background: .blue),
            size: 56,
            cornerRadius: 12
        )
        AppIcon(
            source: .file(URL(fileURLWithPath: "/tmp/does-not-exist.png")),
            size: 88,
            cornerRadius: 18
        )
    }
    .padding()
}
