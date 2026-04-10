import SwiftUI

struct SavedMomentsView: View {
    @EnvironmentObject var store: RecordingSessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMarker: MomentMarker?
    @State private var showExportSheet  = false

    var body: some View {
        NavigationStack {
            Group {
                if store.moments.isEmpty {
                    ContentUnavailableView(
                        "No Saved Moments",
                        systemImage: "bookmark.slash",
                        description: Text("Tap "Save Last \(store.currentSession?.rollingWindowMinutes ?? 30) Min" during a game to protect footage.")
                    )
                } else {
                    List(store.moments) { marker in
                        MomentRow(marker: marker)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedMarker = marker
                                showExportSheet = true
                            }
                    }
                }
            }
            .navigationTitle("Saved Moments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showExportSheet) {
                if let marker = selectedMarker {
                    ExportView(marker: marker)
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - MomentRow
// ─────────────────────────────────────────────────────────────────────────────

private struct MomentRow: View {
    let marker: MomentMarker

    private var timeString: String {
        let f = DateFormatter()
        f.timeStyle = .medium
        return f.string(from: marker.triggeredAt)
    }

    private var sourceIcon: String {
        marker.source == .watch ? "applewatch" : "iphone"
    }

    private var statusColor: Color {
        switch marker.status {
        case .protected:   return .green
        case .protecting:  return .orange
        case .failed:      return .red
        case .pending:     return .gray
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: sourceIcon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(marker.displayTitle)
                    .font(.subheadline.weight(.semibold))
                Text("Last \(marker.saveWindowMinutes) min · \(marker.source.rawValue.capitalized)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
