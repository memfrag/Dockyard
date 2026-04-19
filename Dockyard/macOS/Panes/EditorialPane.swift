//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers
import AppDesign
import DockyardEngine

struct EditorialPane: View {

    @Environment(DockyardEngine.self) private var engine

    @State private var draft = EditorialDraft()
    @State private var statusMessage: String?

    var body: some View {
        Pane {
            NavigationStack {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 24) {
                        PaneHeader("Editorial", subtitle: "Authoring")

                        exportBar

                        titleSection
                        editorsPickSection
                        highlightsSection
                        sectionsListSection
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(32)
                }
            }
        }
        .navigationTitle("Editorial")
    }

    // MARK: - Export bar

    private var exportBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button("Copy JSON") { copyJSON() }
                Button("Save…") { saveJSON() }
                Button("Load…") { loadJSON() }
                Spacer()
            }
            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Title section

    @ViewBuilder
    private var titleSection: some View {
        @Bindable var draft = draft
        sectionBlock(title: "Page title") {
            TextField("On the shelf this week", text: $draft.title)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Editor's Pick

    @ViewBuilder
    private var editorsPickSection: some View {
        @Bindable var draft = draft

        sectionBlock(title: "Editor's Pick") {
            if let pick = draft.editorsPick {
                @Bindable var pick = pick
                VStack(alignment: .leading, spacing: 10) {
                    appPicker(selection: $pick.appID, label: "App")
                    labeledField("Category") {
                        TextField("Editor's Pick", text: $pick.category)
                            .textFieldStyle(.roundedBorder)
                    }
                    labeledField("Headline") {
                        TextField("Headline", text: $pick.headline, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...3)
                    }
                    labeledField("Description") {
                        TextField("Description", text: $pick.description, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                    }
                    HStack(spacing: 20) {
                        ColorPicker("Gradient top", selection: $pick.gradientStart, supportsOpacity: false)
                        ColorPicker("Gradient bottom", selection: $pick.gradientEnd, supportsOpacity: false)
                    }
                    Button("Remove Editor's Pick", role: .destructive) {
                        draft.editorsPick = nil
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .padding(.top, 4)
                }
            } else {
                Button {
                    draft.editorsPick = EditorsPickDraft(appID: firstCatalogAppID ?? "")
                } label: {
                    Label("Add Editor's Pick", systemImage: "plus.circle")
                }
            }
        }
    }

    // MARK: - Highlights

    @ViewBuilder
    private var highlightsSection: some View {
        @Bindable var draft = draft

        sectionBlock(title: "Highlights") {
            VStack(alignment: .leading, spacing: 12) {
                if draft.highlights.count > 2 {
                    Text("Today renders the first two highlights; additional entries are preserved in the JSON for future use.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                ForEach(draft.highlights) { highlight in
                    highlightRow(highlight)
                }

                Button {
                    draft.highlights.append(HighlightDraft(appID: firstCatalogAppID ?? ""))
                } label: {
                    Label("Add highlight", systemImage: "plus.circle")
                }
            }
        }
    }

    @ViewBuilder
    private func highlightRow(_ highlight: HighlightDraft) -> some View {
        @Bindable var highlight = highlight
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Highlight")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    draft.highlights.removeAll { $0.id == highlight.id }
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
            appPicker(selection: $highlight.appID, label: "App")
            labeledField("Category") {
                TextField("New to Dockyard", text: $highlight.category)
                    .textFieldStyle(.roundedBorder)
            }
            labeledField("Description") {
                TextField("Description", text: $highlight.description, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...3)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.gray.opacity(0.08))
        )
    }

    // MARK: - Curated sections

    @ViewBuilder
    private var sectionsListSection: some View {
        @Bindable var draft = draft

        sectionBlock(title: "Curated sections") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(draft.sections) { section in
                    sectionRow(section)
                }

                Button {
                    draft.sections.append(SectionDraft())
                } label: {
                    Label("Add section", systemImage: "plus.circle")
                }
            }
        }
    }

    @ViewBuilder
    private func sectionRow(_ section: SectionDraft) -> some View {
        @Bindable var section = section
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Section")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    draft.sections.removeAll { $0.id == section.id }
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
            labeledField("Title") {
                TextField("For your team", text: $section.title)
                    .textFieldStyle(.roundedBorder)
            }
            labeledField("Subtitle (optional)") {
                TextField("Picked for you…", text: $section.subtitle)
                    .textFieldStyle(.roundedBorder)
            }
            sectionAppList(section: section)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.gray.opacity(0.08))
        )
    }

    @ViewBuilder
    private func sectionAppList(section: SectionDraft) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Apps")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if section.appIDs.isEmpty {
                Text("No apps added.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(section.appIDs, id: \.self) { appID in
                        HStack {
                            Text(displayName(for: appID))
                                .font(.subheadline)
                            Text(appID)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                section.appIDs.removeAll { $0 == appID }
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                        }
                    }
                }
            }

            Menu {
                ForEach(engine.catalog) { entry in
                    Button(entry.displayName) {
                        if !section.appIDs.contains(entry.id) {
                            section.appIDs.append(entry.id)
                        }
                    }
                }
            } label: {
                Label("Add app", systemImage: "plus.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
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

    @ViewBuilder
    private func appPicker(selection: Binding<String>, label: String) -> some View {
        labeledField(label) {
            Picker("", selection: selection) {
                if engine.catalog.isEmpty {
                    Text("Catalog is empty").tag("")
                } else {
                    if !engine.catalog.contains(where: { $0.id == selection.wrappedValue }) {
                        Text("Select an app").tag(selection.wrappedValue)
                    }
                    ForEach(engine.catalog) { entry in
                        Text("\(entry.displayName)  ·  \(entry.id)").tag(entry.id)
                    }
                }
            }
            .labelsHidden()
        }
    }

    // MARK: - Helpers

    private var firstCatalogAppID: CatalogEntry.ID? {
        engine.catalog.first?.id
    }

    private func displayName(for appID: CatalogEntry.ID) -> String {
        engine.catalog.first(where: { $0.id == appID })?.displayName ?? "(unknown)"
    }

    // MARK: - Serialize / deserialize

    private func buildEditorial() -> Editorial {
        Editorial(
            schemaVersion: Editorial.currentSchemaVersion,
            generatedAt: Date(),
            today: draft.asTodayEditorial()
        )
    }

    private func encodedJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(buildEditorial())
    }

    private func copyJSON() {
        do {
            let data = try encodedJSON()
            let string = String(data: data, encoding: .utf8) ?? ""
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(string, forType: .string)
            statusMessage = "Copied editorial.json to clipboard."
        } catch {
            statusMessage = "Failed to encode: \(error.localizedDescription)"
        }
    }

    private func saveJSON() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "editorial.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try encodedJSON()
            try data.write(to: url, options: .atomic)
            statusMessage = "Saved to \(url.path)."
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    private func loadJSON() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let editorial = try Editorial.decode(data)
            draft.replace(with: editorial)
            statusMessage = "Loaded \(url.lastPathComponent)."
        } catch {
            statusMessage = "Load failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Draft models

@Observable
@MainActor
final class EditorialDraft {
    var title: String = "On the shelf this week"
    var editorsPick: EditorsPickDraft?
    var highlights: [HighlightDraft] = []
    var sections: [SectionDraft] = []

    func asTodayEditorial() -> TodayEditorial {
        TodayEditorial(
            title: title,
            editorsPick: editorsPick.map { pick in
                EditorsPickItem(
                    appID: pick.appID,
                    category: pick.category,
                    headline: pick.headline,
                    description: pick.description,
                    gradient: [pick.gradientStart.hexString, pick.gradientEnd.hexString]
                )
            },
            highlights: highlights.map {
                HighlightItem(appID: $0.appID, category: $0.category, description: $0.description)
            },
            sections: sections.map {
                CuratedSection(
                    title: $0.title,
                    subtitle: $0.subtitle.isEmpty ? nil : $0.subtitle,
                    appIDs: $0.appIDs
                )
            }
        )
    }

    func replace(with editorial: Editorial) {
        let today = editorial.today
        title = today?.title ?? ""
        editorsPick = today?.editorsPick.map { pick in
            let start = Color(hex: pick.gradient.first ?? "") ?? EditorsPickBanner.defaultGradient[0]
            let end = Color(hex: pick.gradient.dropFirst().first ?? "") ?? EditorsPickBanner.defaultGradient[1]
            return EditorsPickDraft(
                appID: pick.appID,
                category: pick.category,
                headline: pick.headline,
                description: pick.description,
                gradientStart: start,
                gradientEnd: end
            )
        }
        highlights = today?.highlights.map {
            HighlightDraft(appID: $0.appID, category: $0.category, description: $0.description)
        } ?? []
        sections = today?.sections.map {
            SectionDraft(title: $0.title, subtitle: $0.subtitle ?? "", appIDs: $0.appIDs)
        } ?? []
    }
}

@Observable
@MainActor
final class EditorsPickDraft: Identifiable {
    let id = UUID()
    var appID: CatalogEntry.ID
    var category: String
    var headline: String
    var description: String
    var gradientStart: Color
    var gradientEnd: Color

    init(
        appID: CatalogEntry.ID,
        category: String = "Editor's Pick",
        headline: String = "",
        description: String = "",
        gradientStart: Color = EditorsPickBanner.defaultGradient[0],
        gradientEnd: Color = EditorsPickBanner.defaultGradient[1]
    ) {
        self.appID = appID
        self.category = category
        self.headline = headline
        self.description = description
        self.gradientStart = gradientStart
        self.gradientEnd = gradientEnd
    }
}

@Observable
@MainActor
final class HighlightDraft: Identifiable {
    let id = UUID()
    var appID: CatalogEntry.ID
    var category: String
    var description: String

    init(appID: CatalogEntry.ID, category: String = "New to Dockyard", description: String = "") {
        self.appID = appID
        self.category = category
        self.description = description
    }
}

@Observable
@MainActor
final class SectionDraft: Identifiable {
    let id = UUID()
    var title: String
    var subtitle: String
    var appIDs: [CatalogEntry.ID]

    init(title: String = "", subtitle: String = "", appIDs: [CatalogEntry.ID] = []) {
        self.title = title
        self.subtitle = subtitle
        self.appIDs = appIDs
    }
}

#Preview {
    EditorialPane()
        .previewEnvironment()
}
