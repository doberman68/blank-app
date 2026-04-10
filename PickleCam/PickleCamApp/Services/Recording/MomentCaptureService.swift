import Foundation

/// Resolves a "save last N minutes" event into a concrete set of segments,
/// marks them protected, and returns the created MomentMarker.
final class MomentCaptureService {

    private let segmentStore: SegmentIndexStore

    init(segmentStore: SegmentIndexStore) {
        self.segmentStore = segmentStore
    }

    // MARK: - Capture

    /// Creates a MomentMarker, locks all overlapping segments, and returns the marker.
    /// Must be called on the MainActor (segmentStore mutations are @MainActor).
    @MainActor
    @discardableResult
    func captureNow(
        sessionId:         UUID,
        source:            MomentMarker.Source,
        windowMinutes:     Int
    ) -> MomentMarker {
        var marker = MomentMarker(
            sessionId:         sessionId,
            source:            source,
            saveWindowMinutes: windowMinutes
        )
        marker.status = .protecting

        let idsToProtect = segmentsOverlapping(marker: marker).map { $0.id }
        segmentStore.protect(segmentIds: Set(idsToProtect))
        marker.status = idsToProtect.isEmpty ? .failed : .protected

        return marker
    }

    // MARK: - Queries

    /// Returns segments that fully or partially cover a marker's save window.
    @MainActor
    func segments(for marker: MomentMarker) -> [VideoSegment] {
        segmentsOverlapping(marker: marker)
    }

    /// Total protected duration across all moments for a session.
    @MainActor
    func protectedDuration(for sessionId: UUID) -> TimeInterval {
        segmentStore
            .segments(for: sessionId)
            .filter { $0.isProtected }
            .reduce(0) { $0 + $1.duration }
    }

    // MARK: - Private

    @MainActor
    private func segmentsOverlapping(marker: MomentMarker) -> [VideoSegment] {
        segmentStore
            .segments(for: marker.sessionId)
            .filter { $0.overlaps(from: marker.windowStart, to: marker.triggeredAt) }
    }
}
