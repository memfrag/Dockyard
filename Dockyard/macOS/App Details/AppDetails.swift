//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import AppDesign
import DockyardEngine
import MarkdownUI

struct AppDetailsView: View {

    @Environment(DockyardEngine.self) private var engine

    @Environment(\.openURL) private var openURL

    @State private var iconURL: URL?
    @State private var aboutDocument: MarkdownDocument?
    @State private var releaseNotesDocument: MarkdownDocument?

    private let entry: CatalogEntry

    init(_ entry: CatalogEntry) {
        self.entry = entry
    }

    var body: some View {
        Pane {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 24) {
                        AppIcon(
                            source: AppCardFactory.iconSource(for: entry, iconURL: iconURL),
                            size: 128,
                            cornerRadius: 28
                        )
                        .shadow(
                            color: .black.opacity(0.3),
                            radius: 8,
                            x: 0,
                            y: 6
                        )

                        VStack(alignment: .leading) {
                            AppDetailsHeader(
                                entry.displayName,
                                subtitle: entry.category,
                                description: entry.summary,
                                channel: entry.channel.stringIfNotRelease
                            )
                            .padding(.bottom, 16)

                            HStack {
                                actionButton

                                if let githubURL = entry.github?.url {
                                    githubButton(url: githubURL)
                                }
                            }
                        }
                    }

                    Divider()
                        .opacity(0.5)
                        .padding(.top, 12)

                    HStack(alignment: .top, spacing: 24) {
                        AppDetailProperty("Version", value: entry.version)
                        AppDetailProperty("Size", value: entry.dmgSize.formatted(.byteCount(style: .binary)))
                        AppDetailProperty("Requires", value: "macOS 26")
                        AppDetailProperty("Developer", value: "Martin Johannesson")
                    }

                    if !entry.screenshotURLs.isEmpty {
                        Divider()
                            .opacity(0.5)
                        ScreenshotsSection(urls: entry.screenshotURLs, edgePadding: 32)
                    }

                    if let releaseNotesDocument {
                        Divider()
                            .opacity(0.5)
                        VStack(alignment: .leading, spacing: 8) {
                            AppDetailsSectionHeader("What's New in \(entry.version)")
                            Markdown(releaseNotesDocument, lazy: false)
                                .markdownStyle(MarkdownStyle())
                        }
                    }

                    if let aboutDocument {
                        Divider()
                            .opacity(0.5)
                        VStack(alignment: .leading, spacing: 8) {
                            AppDetailsSectionHeader("About")
                            Markdown(aboutDocument, lazy: false)
                                .markdownStyle(MarkdownStyle())
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(32)
            }
        }
        .task(id: entry.id) {
            iconURL = try? await engine.iconFile(for: entry.id)
        }
        .task(id: entry.aboutURL) {
            await loadAbout()
        }
        .task(id: entry.releaseNotes) {
            releaseNotesDocument = parseMarkdown(entry.releaseNotes)
        }
    }

    // MARK: - Action button

    @ViewBuilder
    private var actionButton: some View {
        let title = AppCardFactory.actionTitle(for: entry, engine: engine)
        let enabled = AppCardFactory.actionEnabled(for: entry, engine: engine)
        let progress = (engine.phases[entry.id] ?? .idle).downloadFraction

        VStack(alignment: .leading, spacing: 10) {
            Button {
                AppCardFactory.performAction(for: entry, engine: engine)
            } label: {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(enabled ? .white : .white.opacity(0.3))
                    .frame(minWidth: 50)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.accentColor, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!enabled)

            if let progress {
                ProgressView(value: max(0, min(1, progress)))
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                    .frame(maxWidth: 320)
            }
        }
    }

    @ViewBuilder private func githubButton(url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            HStack(spacing: 4) {
                Image(.Logo.gitHubLogo)
                    .resizable()
                    .frame(width: 16, height: 16)
                Text("GitHub")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(minWidth: 70)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.25), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Markdown loading

    private func loadAbout() async {
        guard let url = entry.aboutURL else {
            aboutDocument = nil
            return
        }
        guard
            let (data, _) = try? await URLSession.shared.data(from: url),
            let text = String(data: data, encoding: .utf8),
            !text.isEmpty
        else {
            aboutDocument = nil
            return
        }
        aboutDocument = parseMarkdown(text)
    }

    private func parseMarkdown(_ source: String?) -> MarkdownDocument? {
        guard let source else { return nil }
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return try? MarkdownDocument(trimmed)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Dark Mode") {
    AppDetailsView(.Mock.repoRanger)
        .previewEnvironment()
}

#Preview("Light Mode") {
    AppDetailsView(.Mock.repoRanger)
        .colorScheme(.light)
        .previewEnvironment()
}
#endif
