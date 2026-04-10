import Foundation

/// Lightweight models used only on the watch target.
/// Heavy models (VideoSegment, MomentMarker, etc.) live on the phone.

// MARK: - Outbound command payload

struct SaveMomentPayload: Encodable {
    let type:          String  = "saveMoment"
    let windowMinutes: Int

    func asDictionary() -> [String: Any] {
        ["type": type, "windowMinutes": windowMinutes]
    }
}

// MARK: - Watch → phone message keys

enum WatchMessageKey {
    static let type          = "type"
    static let windowMinutes = "windowMinutes"
    static let status        = "status"
}
