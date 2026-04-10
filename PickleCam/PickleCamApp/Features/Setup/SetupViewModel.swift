import Foundation
import Combine

final class SetupViewModel: ObservableObject {
    @Published var cameraPosition:       RecordingSession.CameraPosition  = .back
    @Published var resolutionPreset:     RecordingSession.ResolutionPreset = .hd1080p
    @Published var rollingWindowMinutes: Int                               = 30
    @Published var segmentLengthSeconds: TimeInterval                      = 120
    @Published var audioEnabled:         Bool                              = true
}
