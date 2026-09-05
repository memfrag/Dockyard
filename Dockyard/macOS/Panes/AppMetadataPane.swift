//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers
import AppDesign
import DockyardEngine

/// Authoring UI for the `.dockyard/` folder an app repo publishes about itself.
///
/// Point it at a local checkout and it loads whatever metadata is already there,
/// creating the folder on save when there is none. This is the same layout the
/// manifest tool reads over the GitHub API, so what's edited here is what the
/// catalog will show once it's committed and pushed.
struct AppMetadataPane: View {

    /// Categories the sidebar has panes for. Anything else still loads and saves
    /// fine; it just won't have a category pane of its own.
    private static let knownCategories = ["Design", "Development", "Entertainment", "Finance", "Productivity"]

    @State private var draft = AppMetadataDraft()
    @State private var status: Status?

    private enum Status {
        case info(String)
        case failure(String)

        var text: String {
            switch self {
            case .info(let message), .failure(let message): return message
            }
        }
        var isFailure: Bool { if case .failure = self { return true } else { return false } }
    }

    var body: some View {
        Pane {
            NavigationStack {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 24) {
                        PaneHeader("App Metadata", subtitle: "Authoring")

                        repositoryBar

                        if draft.repositoryURL != nil {
                            metadataSection
                            aboutSection
                            iconSection
                            screenshotsSection
                        } else {
                            emptyState
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(32)
                }
            }
        }
        .navigationTitle("App Metadata")
    }

    // MARK: - Repository bar

    private var repositoryBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button("Choose Repo…") { chooseRepository() }
                if let url = draft.repositoryURL {
                    Button("Reload") { load(from: url) }
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([draft.dockyardDirectoryURL ?? url])
                    }
                    Spacer()
                    Button("Save") { save() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!draft.canSave)
                }
            }

            if let url = draft.repositoryURL {
                Text(url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if let status {
                Text(status.text)
                    .font(.caption)
                    .foregroundStyle(status.isFailure ? .red : .secondary)
            }
        }
    }

    private var emptyState: some View {
        sectionBlock(title: "No repo selected") {
            Text("Choose a checkout of an app repo. Its .dockyard folder is loaded if it has one, and created when you save if it doesn't.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Metadata

    @ViewBuilder
    private var metadataSection: some View {
        @Bindable var draft = draft

        sectionBlock(title: "dockyard.json") {
            VStack(alignment: .leading, spacing: 10) {
                if draft.isNewFolder {
                    Text("This repo has no .dockyard folder yet. Saving will create one.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                labeledField("Bundle Identifier") {
                    TextField("com.example.YourApp", text: $draft.id)
                        .textFieldStyle(.roundedBorder)
                }
                Text("Must match the built app's CFBundleIdentifier — the installer verifies it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                labeledField("Display Name") {
                    TextField("Your App", text: $draft.displayName)
                        .textFieldStyle(.roundedBorder)
                }

                labeledField("Category") {
                    Picker("", selection: $draft.category) {
                        ForEach(categoryOptions, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .labelsHidden()
                }

                labeledField("Summary") {
                    TextField("One short line, shown on the app card.", text: $draft.summary)
                        .textFieldStyle(.roundedBorder)
                }
                Text(summaryHint)
                    .font(.caption)
                    .foregroundStyle(draft.summary.count > 60 ? .orange : .secondary)

                labeledField("Asset Pattern") {
                    TextField("^YourApp-.*\\.dmg$", text: $draft.assetPattern)
                        .textFieldStyle(.roundedBorder)
                }
                Text("Optional regex picking the DMG out of a release. Leave empty to take the first one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                labeledField("Channel") {
                    Picker("", selection: $draft.channel) {
                        Text("Release").tag(ReleaseChannel.release)
                        Text("Beta").tag(ReleaseChannel.beta)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }

                if !draft.missingRequiredFields.isEmpty {
                    Text("The catalog build needs \(draft.missingRequiredFields.joined(separator: ", ")) before this app can be published.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var categoryOptions: [String] {
        var options = Self.knownCategories
        // Keep a category the repo already had, even if it isn't one of ours.
        if !draft.category.isEmpty, !options.contains(draft.category) {
            options.append(draft.category)
        }
        return options
    }

    private var summaryHint: String {
        draft.summary.count > 60
            ? "\(draft.summary.count) characters — the card shows one line, so this will be truncated."
            : "Shown on the app card, which renders a single line."
    }

    // MARK: - About

    @ViewBuilder
    private var aboutSection: some View {
        @Bindable var draft = draft

        sectionBlock(title: "about.md") {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $draft.about)
                    .font(.body.monospaced())
                    .frame(minHeight: 160)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.gray.opacity(0.08))
                    )
                Text("Markdown, rendered as the About section. Leave empty to omit the section entirely.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Icon

    @ViewBuilder
    private var iconSection: some View {
        sectionBlock(title: "AppIcon.png") {
            HStack(alignment: .top, spacing: 16) {
                if let iconURL = draft.iconURL, let image = NSImage(contentsOf: iconURL) {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .id(draft.iconRevision)
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 96, height: 96)
                        .overlay(Image(systemName: "app.dashed").font(.largeTitle).foregroundStyle(.secondary))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(draft.iconURL == nil
                         ? "No icon yet. The catalog can't list an app without one."
                         : "Shown on the card and the app page.")
                        .font(.subheadline)
                        .foregroundStyle(draft.iconURL == nil ? .orange : .secondary)
                    Button("Choose Image…") { chooseIcon() }
                    Text("Any image; it's converted to a 512×512 PNG.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    // MARK: - Screenshots

    @ViewBuilder
    private var screenshotsSection: some View {
        sectionBlock(title: "Screenshots") {
            VStack(alignment: .leading, spacing: 12) {
                if draft.screenshotURLs.isEmpty {
                    Text("None. The app page omits the section when there are no screenshots.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(draft.screenshotURLs, id: \.self) { url in
                        HStack(spacing: 12) {
                            if let image = NSImage(contentsOf: url) {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 136, height: 84)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            Text(url.lastPathComponent)
                                .font(.subheadline)
                            Spacer()
                            Button("Remove", role: .destructive) { removeScreenshot(url) }
                                .buttonStyle(.plain)
                                .foregroundStyle(.red)
                        }
                    }
                }

                Button("Add Screenshot…") { addScreenshot() }
                Text("680×420 pixels renders crisp. Files are numbered in the order you add them, which is the order they appear.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func chooseRepository() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose the repo folder — the one containing .dockyard, not .dockyard itself."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        load(from: url)
    }

    private func load(from url: URL) {
        do {
            let folder = try DockyardFolder.load(from: url)
            draft.replace(with: folder)
            status = .info(folder.isEmpty
                           ? "No .dockyard folder here yet — fill in the fields and save to create one."
                           : "Loaded \(url.lastPathComponent).")
        } catch {
            // Most likely a malformed dockyard.json. Refusing to load beats
            // silently replacing whatever is on disk on the next save.
            draft.clear()
            status = .failure("Could not load: \(error.localizedDescription)")
        }
    }

    private func save() {
        do {
            try draft.folder().save()
            status = .info("Saved to \(draft.dockyardDirectoryURL?.path ?? "the repo"). Commit and push to publish it.")
        } catch {
            status = .failure("Save failed: \(error.localizedDescription)")
        }
    }

    private func chooseIcon() {
        guard let folder = try? draft.folder() else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try folder.installIcon(from: url)
            draft.iconURL = folder.defaultIconURL
            draft.iconRevision += 1
            status = .info("Icon written to .dockyard/AppIcon.png.")
        } catch {
            status = .failure("Could not use that image: \(error.localizedDescription)")
        }
    }

    private func addScreenshot() {
        guard let folder = try? draft.folder() else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .gif, .webP]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        do {
            for url in panel.urls {
                try folder.addScreenshot(from: url)
            }
            draft.screenshotURLs = DockyardFolder.screenshots(in: folder.screenshotsDirectoryURL)
            status = .info("Added \(panel.urls.count) screenshot\(panel.urls.count == 1 ? "" : "s").")
        } catch {
            status = .failure("Could not add screenshot: \(error.localizedDescription)")
        }
    }

    private func removeScreenshot(_ url: URL) {
        guard let folder = try? draft.folder() else { return }
        do {
            try folder.removeScreenshot(at: url)
            draft.screenshotURLs = DockyardFolder.screenshots(in: folder.screenshotsDirectoryURL)
            status = .info("Removed \(url.lastPathComponent).")
        } catch {
            status = .failure("Could not remove: \(error.localizedDescription)")
        }
    }

    // MARK: - Building blocks

    @ViewBuilder
    private func sectionBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func labeledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }
}

// MARK: - Draft

@Observable
@MainActor
final class AppMetadataDraft {

    var repositoryURL: URL?
    var isNewFolder = false

    var id: String = ""
    var displayName: String = ""
    var category: String = "Productivity"
    var summary: String = ""
    var assetPattern: String = ""
    var channel: ReleaseChannel = .release
    var about: String = ""

    var iconURL: URL?
    var screenshotURLs: [URL] = []
    /// Bumped when the icon is replaced, so SwiftUI reloads the preview from a
    /// path that hasn't changed.
    var iconRevision = 0

    var dockyardDirectoryURL: URL? { repositoryURL?.appending(path: ".dockyard") }

    /// An id is the one thing the catalog cannot do without.
    var canSave: Bool { repositoryURL != nil && !id.trimmingCharacters(in: .whitespaces).isEmpty }

    /// What the manifest build still needs. Everything here is optional in the
    /// file format but required once the app is in the catalog.
    var missingRequiredFields: [String] {
        var missing: [String] = []
        if displayName.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("a display name") }
        if category.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("a category") }
        if summary.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("a summary") }
        if iconURL == nil { missing.append("an icon") }
        return missing
    }

    func replace(with folder: DockyardFolder) {
        repositoryURL = folder.repositoryURL
        isNewFolder = folder.metadata == nil
        id = folder.metadata?.id ?? ""
        displayName = folder.metadata?.displayName ?? ""
        category = folder.metadata?.category ?? "Productivity"
        summary = folder.metadata?.summary ?? ""
        assetPattern = folder.metadata?.assetPattern ?? ""
        channel = folder.metadata?.channel ?? .release
        about = folder.about ?? ""
        iconURL = folder.iconURL
        screenshotURLs = folder.screenshotURLs
        iconRevision += 1
    }

    func clear() {
        repositoryURL = nil
        isNewFolder = false
        iconURL = nil
        screenshotURLs = []
    }

    func folder() throws -> DockyardFolder {
        guard let repositoryURL else { throw DockyardFolderError.noMetadataToSave }
        return DockyardFolder(
            repositoryURL: repositoryURL,
            metadata: RepoMetadata(
                id: id.trimmingCharacters(in: .whitespaces),
                displayName: displayName,
                category: category,
                summary: summary,
                assetPattern: assetPattern,
                channel: channel
            ),
            about: about,
            iconURL: iconURL,
            screenshotURLs: screenshotURLs
        )
    }
}
