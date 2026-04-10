import Foundation

/// A final assembled video file that was exported to Photos or Files.
struct ExportedClip: Identifiable, Codable, Sendable {
    let id: UUID
    let sessionId: UUID
    let markerId: UUID?           // nil if exported without a specific marker
    var fileURL: URL
    var startedAt: Date
    var endedAt: Date
    var duration: TimeInterval    // seconds
    var fileSizeBytes: Int64
    var exportedAt: Date

    var displayDuration: String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
