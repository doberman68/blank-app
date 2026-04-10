import Foundation

/// Metadata for one rolling segment file written by the RollingRecorder.
struct VideoSegment: Identifiable, Codable, Sendable {
    let id: UUID
    let sessionId: UUID
    var fileURL: URL
    var startedAt: Date
    var endedAt: Date?
    var duration: TimeInterval     // seconds; set when finalized
    var fileSizeBytes: Int64       // set when finalized
    var isProtected: Bool          // true once a MomentMarker covers this segment

    // MARK: - Convenience

    var isFinalized: Bool { endedAt != nil }

    /// Whether this segment's time range overlaps [from, to).
    func overlaps(from: Date, to: Date) -> Bool {
        let end = endedAt ?? Date()
        return startedAt < to && end > from
    }
}
