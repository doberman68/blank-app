import Foundation

/// Top-level record for a single game recording session.
struct RecordingSession: Identifiable, Codable, Sendable {
    let id: UUID
    var startedAt: Date
    var endedAt: Date?
    var status: Status
    var cameraPosition: CameraPosition
    var resolutionPreset: ResolutionPreset
    var rollingWindowMinutes: Int
    var segmentLengthSeconds: TimeInterval

    // MARK: - Nested types

    enum Status: String, Codable, Sendable {
        case idle
        case preparing
        case recording
        case savingMoment
        case exporting
        case error
    }

    enum CameraPosition: String, Codable, Sendable {
        case back
        case front
    }

    enum ResolutionPreset: String, Codable, Sendable, CaseIterable {
        case hd720p  = "hd1280x720"
        case hd1080p = "hd1920x1080"
        case uhd4k   = "hd4K3840x2160"

        var displayName: String {
            switch self {
            case .hd720p:  return "720p HD"
            case .hd1080p: return "1080p HD"
            case .uhd4k:   return "4K UHD"
            }
        }

        /// Approximate megabits-per-second at this preset (H.264 baseline).
        var approximateBitrateMbps: Double {
            switch self {
            case .hd720p:  return 5
            case .hd1080p: return 8
            case .uhd4k:   return 25
            }
        }
    }

    // MARK: - Init

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        cameraPosition: CameraPosition = .back,
        resolutionPreset: ResolutionPreset = .hd1080p,
        rollingWindowMinutes: Int = 30,
        segmentLengthSeconds: TimeInterval = 120
    ) {
        self.id = id
        self.startedAt = startedAt
        self.status = .idle
        self.cameraPosition = cameraPosition
        self.resolutionPreset = resolutionPreset
        self.rollingWindowMinutes = rollingWindowMinutes
        self.segmentLengthSeconds = segmentLengthSeconds
    }
}
