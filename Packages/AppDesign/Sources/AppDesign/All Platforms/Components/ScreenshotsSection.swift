import SwiftUI

public struct ScreenshotsSection: View {

    private let urls: [URL]
    private let edgePadding: CGFloat

    @State private var visibleIndex: Int? = 0

    public init(urls: [URL], edgePadding: CGFloat) {
        self.urls = urls
        self.edgePadding = edgePadding
    }

    public var body: some View {
        if urls.isEmpty {
            EmptyView()
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                AppDetailsSectionHeader("Screenshots")
                Spacer()
                pagingButtons
            }

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                        screenshot(url: url)
                            .id(index)
                    }
                }
                .scrollTargetLayout()
                .padding(.bottom, 12)
            }
            .scrollPosition(id: $visibleIndex, anchor: .leading)
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, edgePadding, for: .scrollContent)
            .frame(height: 222)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, -edgePadding)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func screenshot(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                placeholder
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                placeholder.overlay {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }
            @unknown default:
                placeholder
            }
        }
        .frame(width: 320, height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .foregroundStyle(Color.gray.opacity(0.2))
            .frame(width: 320, height: 210)
    }

    private var pagingButtons: some View {
        HStack(spacing: 6) {
            Button {
                scroll(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!canScrollBackward)

            Button {
                scroll(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!canScrollForward)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    // MARK: - Paging

    private var currentIndex: Int {
        visibleIndex ?? 0
    }

    private var canScrollBackward: Bool {
        currentIndex > 0
    }

    private var canScrollForward: Bool {
        currentIndex < urls.count - 1
    }

    private func scroll(by delta: Int) {
        guard !urls.isEmpty else { return }
        let target = (currentIndex + delta).clamped(to: 0...(urls.count - 1))
        guard target != currentIndex else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            visibleIndex = target
        }
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

#Preview {
    ScreenshotsSection(
        urls: [
            URL(string: "https://picsum.photos/id/10/680/420")!,
            URL(string: "https://picsum.photos/id/11/680/420")!,
            URL(string: "https://picsum.photos/id/12/680/420")!
        ],
        edgePadding: 32
    )
    .padding(32)
}
