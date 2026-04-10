import Foundation
import Combine

/// In-memory store for VideoSegment metadata, persisted to JSON on disk.
/// All mutations run on the MainActor so SwiftUI can observe @Published properties.
@MainActor
final class SegmentIndexStore: ObservableObject {

    @Published private(set) var segments: [VideoSegment] = []

    private let persistenceURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        persistenceURL = docs.appendingPathComponent("segment_index.json")
        load()
    }

    // MARK: - Mutations

    func addSegment(_ segment: VideoSegment) {
        segments.append(segment)
        save()
    }

    /// Called when an AVAssetWriter finishes writing a segment file.
    func finalizeSegment(fileURL: URL, endedAt: Date, fileSizeBytes: Int64) {
        guard let idx = segments.firstIndex(where: { $0.fileURL == fileURL }) else { return }
        segments[idx].endedAt      = endedAt
        segments[idx].duration     = endedAt.timeIntervalSince(segments[idx].startedAt)
        segments[idx].fileSizeBytes = fileSizeBytes
        save()
    }

    /// Marks the given segment IDs as protected (exempt from rolling purge).
    func protect(segmentIds: Set<UUID>) {
        for idx in segments.indices where segmentIds.contains(segments[idx].id) {
            segments[idx].isProtected = true
        }
        save()
    }

    /// Deletes the segment record and its backing file from disk.
    func delete(segmentId: UUID) {
        guard let idx = segments.firstIndex(where: { $0.id == segmentId }) else { return }
        try? FileManager.default.removeItem(at: segments[idx].fileURL)
        segments.remove(at: idx)
        save()
    }

    // MARK: - Queries

    func segments(for sessionId: UUID) -> [VideoSegment] {
        segments
            .filter  { $0.sessionId == sessionId }
            .sorted  { $0.startedAt < $1.startedAt }
    }

    /// Finalized, unprotected segments for a session, oldest first.
    func unprotectedSegments(for sessionId: UUID) -> [VideoSegment] {
        segments(for: sessionId)
            .filter { !$0.isProtected && $0.isFinalized }
    }

    func totalDuration(for sessionId: UUID) -> TimeInterval {
        segments(for: sessionId).reduce(0) { $0 + $1.duration }
    }

    // MARK: - Persistence

    private func save() {
        do {
            let data = try JSONEncoder().encode(segments)
            try data.write(to: persistenceURL, options: .atomic)
        } catch {
            print("[SegmentIndexStore] Failed to persist: \(error)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: persistenceURL) else { return }
        segments = (try? JSONDecoder().decode([VideoSegment].self, from: data)) ?? []
        // Drop any entry whose backing file no longer exists
        segments = segments.filter { FileManager.default.fileExists(atPath: $0.fileURL.path) }
        save()
    }
}
