import SwiftUI

public struct ScreenshotsSection: View {

    private let urls: [URL]

    @State private var visibleIndex: Int? = 0

    public init(urls: [URL]) {
        self.urls = urls
    }

    /// The IDs the ScrollView paginates through. Uses URL-backed IDs when
    /// real screenshots are available, otherwise placeholder indices.
    private var indices: [Int] {
        urls.isEmpty ? [0, 1, 2] : Array(urls.indices)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                AppDetailsSectionHeader("Screenshots")
                Spacer()
                pagingButtons
            }

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(indices, id: \.self) { index in
                        screenshot(at: index)
                            .id(index)
                    }
                }
                .scrollTargetLayout()
                .padding(.bottom, 12)
            }
            .scrollPosition(id: $visibleIndex, anchor: .leading)
            .scrollTargetBehavior(.viewAligned)
            .frame(height: 222)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func screenshot(at index: Int) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .foregroundStyle(.teal)
            .frame(width: 340, height: 210)
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
        currentIndex < indices.count - 1
    }

    private func scroll(by delta: Int) {
        let target = (currentIndex + delta).clamped(to: 0...(indices.count - 1))
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
    ScreenshotsSection(urls: [])
        .padding()
}
