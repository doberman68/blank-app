import SwiftUI

struct ExportView: View {
    let marker: MomentMarker
    @EnvironmentObject var store: RecordingSessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var destination: ExportService.Destination = .photoLibrary
    @State private var showShareSheet = false
    @State private var exportedURL:   URL?

    private var segments: [VideoSegment] {
        store.momentService.segments(for: marker)
    }

    private var totalDuration: String {
        let secs = segments.reduce(0.0) { $0 + $1.duration }
        let m    = Int(secs) / 60
        let s    = Int(secs) % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        NavigationStack {
            Form {
                // ── Summary ──────────────────────────────────────────────────
                Section("Clip summary") {
                    LabeledContent("Triggered",  value: marker.triggeredAt.formatted(.dateTime.hour().minute().second()))
                    LabeledContent("Window",     value: "Last \(marker.saveWindowMinutes) min")
                    LabeledContent("Segments",   value: "\(segments.count)")
                    LabeledContent("Duration",   value: totalDuration)
                }

                // ── Destination ───────────────────────────────────────────────
                Section("Save to") {
                    Picker("Destination", selection: $destination) {
                        Label("Photo Library", systemImage: "photo.on.rectangle")
                            .tag(ExportService.Destination.photoLibrary)
                        Label("Files (Documents)", systemImage: "folder")
                            .tag(ExportService.Destination.files)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                // ── Export button / progress ──────────────────────────────────
                Section {
                    if store.exportService.isExporting {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Exporting…")
                                .font(.subheadline)
                            ProgressView(value: store.exportService.exportProgress)
                                .progressViewStyle(.linear)
                        }
                        .padding(.vertical, 4)
                    } else if let clip = store.exportService.lastExportedClip,
                              clip.markerId == marker.id {
                        successRow(clip: clip)
                    } else {
                        Button(action: startExport) {
                            Label("Export Clip", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .listRowBackground(Color.clear)
                        .disabled(segments.isEmpty)
                    }
                }

                if segments.isEmpty {
                    Section {
                        Label("No protected segments found for this moment.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Export Moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportedURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    @ViewBuilder
    private func successRow(clip: ExportedClip) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Export complete!", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.subheadline.weight(.semibold))
            Text("\(clip.displayDuration) · \(ByteCountFormatter.string(fromByteCount: clip.fileSizeBytes, countStyle: .file))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                exportedURL  = clip.fileURL
                showShareSheet = true
            } label: {
                Label("Share…", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }

    private func startExport() {
        Task {
            await store.exportMoment(marker, to: destination)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - UIActivityViewController wrapper
// ─────────────────────────────────────────────────────────────────────────────

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
