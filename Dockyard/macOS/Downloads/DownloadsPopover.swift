//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import AppDesign
import DockyardEngine

struct DownloadsPopover: View {

    @Environment(DockyardEngine.self) private var engine

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if activeRows.isEmpty {
                empty
            } else {
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        ForEach(activeRows, id: \.id) { row in
                            DownloadRow(row: row) {
                                engine.cancel(row.id)
                            }
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .frame(maxHeight: 360)
            }
        }
        .frame(width: 360)
    }

    private var header: some View {
        HStack {
            Text("Downloads")
                .font(.headline)
            Spacer()
            if !activeRows.isEmpty {
                Text("\(activeRows.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("No active downloads")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Row model

    struct Row: Identifiable {
        let id: CatalogEntry.ID
        let title: String
        let phase: InstallPhase
    }

    private var activeRows: [Row] {
        engine.catalog.compactMap { entry in
            let phase = engine.phases[entry.id] ?? .idle
            guard phase.isInFlight else { return nil }
            return Row(id: entry.id, title: entry.displayName, phase: phase)
        }
    }
}

private struct DownloadRow: View {
    let row: DownloadsPopover.Row
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            phaseIcon

            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if case .downloadingDMG(let progress) = row.phase {
                    ProgressView(value: progress.fraction ?? 0)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                } else if row.phase.isInFlight {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                }
            }

            Button {
                onCancel()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Cancel")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var phaseIcon: some View {
        let systemName: String = {
            switch row.phase {
            case .queued: "clock"
            case .downloadingDMG: "arrow.down.circle"
            case .verifyingHash, .verifyingSignature: "checkmark.shield"
            case .mounting: "externaldrive"
            case .copying: "doc.on.doc"
            case .finalizing: "sparkles"
            default: "circle"
            }
        }()
        return Image(systemName: systemName)
            .font(.system(size: 18, weight: .regular))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
    }

    private var subtitle: String {
        switch row.phase {
        case .queued:
            return "Queued"
        case .downloadingDMG(let progress):
            let percent = progress.fraction.map { "\(Int($0 * 100))%" } ?? "…"
            let bytes = ByteCountFormatter.string(fromByteCount: progress.bytesWritten, countStyle: .file)
            let total = progress.bytesExpected > 0
                ? ByteCountFormatter.string(fromByteCount: progress.bytesExpected, countStyle: .file)
                : nil
            if let total {
                return "Downloading — \(bytes) of \(total) (\(percent))"
            }
            return "Downloading — \(bytes)"
        case .verifyingHash:
            return "Verifying hash…"
        case .mounting:
            return "Mounting DMG…"
        case .copying:
            return "Copying to Applications…"
        case .verifyingSignature:
            return "Verifying signature…"
        case .finalizing:
            return "Finalizing…"
        default:
            return ""
        }
    }
}

#Preview {
    DownloadsPopover()
        .previewEnvironment()
}
