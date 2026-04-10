import Foundation

/// Records when the user (or watch) triggered a "save last N minutes" event.
struct MomentMarker: Identifiable, Codable, Sendable {
    let id: UUID
    let sessionId: UUID
    var triggeredAt: Date
    var source: Source
    var saveWindowMinutes: Int
    var status: Status

    // MARK: - Nested types

    enum Source: String, Codable, Sendable {
        case watch
        case phone
    }

    enum Status: String, Codable, Sendable {
        case pending      // just created, protection not yet applied
        case protecting   // segments being locked
        case protected    // all covering segments are marked isProtected
        case failed       // something went wrong
    }

    // MARK: - Convenience

    /// The earliest timestamp this marker is trying to preserve.
    var windowStart: Date {
        Calendar.current.date(
            byAdding: .minute,
            value: -saveWindowMinutes,
            to: triggeredAt
        ) ?? triggeredAt
    }

    /// Human-readable summary for list views.
    var displayTitle: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "Saved at \(formatter.string(from: triggeredAt))"
    }

    // MARK: - Init

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        triggeredAt: Date = Date(),
        source: Source,
        saveWindowMinutes: Int = 30
    ) {
        self.id = id
        self.sessionId = sessionId
        self.triggeredAt = triggeredAt
        self.source = source
        self.saveWindowMinutes = saveWindowMinutes
        self.status = .pending
    }
}
