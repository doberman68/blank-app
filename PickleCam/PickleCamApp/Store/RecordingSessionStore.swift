import Foundation
import Combine

/// The single source of truth for all app state.
/// Injected as an `@EnvironmentObject` into the SwiftUI tree.
@MainActor
final class RecordingSessionStore: ObservableObject {

    // MARK: - Session state

    @Published private(set) var sessionState:     SessionState    = .idle
    @Published private(set) var currentSession:   RecordingSession?
    @Published private(set) var moments:          [MomentMarker]  = []
    @Published private(set) var exportedClips:    [ExportedClip]  = []
    @Published private(set) var lastWatchTrigger: Date?
    @Published private(set) var elapsedSeconds:   Int             = 0

    // MARK: - Services (read-only from views via EnvironmentObject)

    let cameraManager:  CameraSessionManager
    let rollingRecorder: RollingRecorder
    let segmentStore:   SegmentIndexStore
    let momentService:  MomentCaptureService
    let exportService:  ExportService
    let storageManager: StorageManager
    let watchReceiver:  WatchCommandReceiver

    // MARK: - Private

    private var elapsedTimer:   Timer?
    private var cancellables:   Set<AnyCancellable> = []

    // MARK: - Session state machine

    enum SessionState: Equatable {
        case idle
        case preparing
        case recording
        case savingMoment
        case exporting
        case error(String)

        var isActive: Bool {
            switch self {
            case .recording, .savingMoment: return true
            default: return false
            }
        }
    }

    // MARK: - Init

    init() {
        let segStore  = SegmentIndexStore()
        let storage   = StorageManager()
        let camera    = CameraSessionManager()
        let recorder  = RollingRecorder(segmentStore: segStore, storageManager: storage)
        let moments   = MomentCaptureService(segmentStore: segStore)
        let exporter  = ExportService()
        let watch     = WatchCommandReceiver()

        self.segmentStore    = segStore
        self.storageManager  = storage
        self.cameraManager   = camera
        self.rollingRecorder = recorder
        self.momentService   = moments
        self.exportService   = exporter
        self.watchReceiver   = watch

        wireWatchReceiver()
        bridgeCameraErrors()
    }

    // MARK: - Session lifecycle

    func prepareSession(
        rollingWindowMinutes: Int      = 30,
        segmentLength:        TimeInterval = 120,
        cameraPosition:       RecordingSession.CameraPosition  = .back,
        resolutionPreset:     RecordingSession.ResolutionPreset = .hd1080p
    ) async {
        sessionState = .preparing

        let session = RecordingSession(
            cameraPosition:    cameraPosition,
            resolutionPreset:  resolutionPreset,
            rollingWindowMinutes: rollingWindowMinutes,
            segmentLengthSeconds: segmentLength
        )
        currentSession = session

        // Configure recorder
        var config = RollingRecorder.Configuration()
        config.segmentDuration      = segmentLength
        config.rollingWindowMinutes = rollingWindowMinutes
        config.videoSettings        = videoSettings(for: resolutionPreset)
        rollingRecorder.updateConfiguration(config)

        // Camera preset
        cameraManager.qualityPreset = avPreset(for: resolutionPreset)

        // Request permissions & configure
        await cameraManager.requestPermissionsAndConfigure()
    }

    func startRecording() {
        guard
            let session = currentSession,
            cameraManager.permissionStatus == .authorized
        else {
            sessionState = .error("Camera permission not granted.")
            return
        }

        cameraManager.setSampleBufferDelegate(rollingRecorder)
        cameraManager.startSession()
        rollingRecorder.startRecording(
            sessionId:     session.id,
            videoTransform: cameraManager.currentVideoTransform()
        )

        var updated          = session
        updated.startedAt    = Date()
        updated.status       = .recording
        currentSession       = updated
        sessionState         = .recording

        storageManager.startMonitoring()
        startElapsedTimer()
    }

    func stopRecording() {
        stopElapsedTimer()
        rollingRecorder.stopRecording()
        cameraManager.stopSession()
        storageManager.stopMonitoring()

        currentSession?.endedAt = Date()
        currentSession?.status  = .idle
        sessionState            = .idle
        elapsedSeconds          = 0
    }

    // MARK: - Moment saving

    func saveMoment(source: MomentMarker.Source) {
        guard let session = currentSession, sessionState == .recording else { return }
        sessionState = .savingMoment

        let marker = momentService.captureNow(
            sessionId:     session.id,
            source:        source,
            windowMinutes: session.rollingWindowMinutes
        )
        moments.append(marker)

        if source == .watch { lastWatchTrigger = Date() }
        sendLocalNotification(for: marker)
        sessionState = .recording
    }

    // MARK: - Export

    func exportMoment(_ marker: MomentMarker, to dest: ExportService.Destination) async {
        guard sessionState != .exporting else { return }
        sessionState = .exporting

        let segs = momentService.segments(for: marker)
        do {
            let clip = try await exportService.export(marker: marker, segments: segs, to: dest)
            exportedClips.append(clip)
            sessionState = .idle
        } catch {
            sessionState = .error(error.localizedDescription)
        }
    }

    func dismissError() {
        sessionState = .idle
    }

    // MARK: - Private helpers

    private func wireWatchReceiver() {
        watchReceiver.onSaveMoment = { [weak self] _ in
            Task { @MainActor in self?.saveMoment(source: .watch) }
        }
    }

    private func bridgeCameraErrors() {
        cameraManager.$error
            .compactMap { $0 }
            .sink { [weak self] cameraError in
                self?.sessionState = .error(
                    cameraError.errorDescription ?? "Unknown camera error."
                )
            }
            .store(in: &cancellables)
    }

    private func startElapsedTimer() {
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.elapsedSeconds += 1 }
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    private func sendLocalNotification(for marker: MomentMarker) {
        let content        = UNMutableNotificationContent()
        content.title      = "Moment Saved"
        content.body       = "Last \(marker.saveWindowMinutes) min protected (\(marker.source.rawValue))."
        content.sound      = .default
        let request        = UNNotificationRequest(
            identifier: marker.id.uuidString,
            content:    content,
            trigger:    nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Preset translation helpers

    private func avPreset(for preset: RecordingSession.ResolutionPreset) -> AVCaptureSession.Preset {
        switch preset {
        case .hd720p:  return .hd1280x720
        case .hd1080p: return .hd1920x1080
        case .uhd4k:   return .hd4K3840x2160
        }
    }

    private func videoSettings(
        for preset: RecordingSession.ResolutionPreset
    ) -> [String: Any] {
        let (w, h): (Int, Int) = {
            switch preset {
            case .hd720p:  return (1280, 720)
            case .hd1080p: return (1920, 1080)
            case .uhd4k:   return (3840, 2160)
            }
        }()
        let bitrate = Int(preset.approximateBitrateMbps * 1_000_000)
        return [
            AVVideoCodecKey:  AVVideoCodecType.h264,
            AVVideoWidthKey:  w,
            AVVideoHeightKey: h,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoProfileLevelKey:   AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
    }
}

// Bring in UserNotifications for the save notification helper
import AVFoundation
import UserNotifications
