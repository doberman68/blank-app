import AVFoundation
import UIKit
import Combine

/// Owns and configures the AVCaptureSession.
/// Exposes AVCaptureVideoDataOutput and AVCaptureAudioDataOutput so that
/// RollingRecorder can attach itself as the sample-buffer delegate.
@MainActor
final class CameraSessionManager: ObservableObject {

    // MARK: - Published state

    @Published private(set) var isSessionRunning = false
    @Published private(set) var permissionStatus: PermissionStatus = .undetermined
    @Published private(set) var error: CameraError?

    // MARK: - Session (read by CameraPreviewView)

    let session = AVCaptureSession()
    private(set) var currentCameraPosition: AVCaptureDevice.Position = .back
    var qualityPreset: AVCaptureSession.Preset = .hd1920x1080

    // MARK: - Outputs (delegates set by RollingRecorder)

    private(set) var videoDataOutput = AVCaptureVideoDataOutput()
    private(set) var audioDataOutput = AVCaptureAudioDataOutput()

    private let sessionQueue   = DispatchQueue(label: "com.picklecam.camera.session",  qos: .userInitiated)
    private let videoDataQueue = DispatchQueue(label: "com.picklecam.camera.video",    qos: .userInitiated)
    private let audioDataQueue = DispatchQueue(label: "com.picklecam.camera.audio",    qos: .userInitiated)

    private weak var videoDelegate: (AVCaptureVideoDataOutputSampleBufferDelegate & AVCaptureAudioDataOutputSampleBufferDelegate)?

    // MARK: - Nested types

    enum PermissionStatus {
        case undetermined, authorized, denied
    }

    enum CameraError: LocalizedError, Equatable {
        case permissionDenied
        case deviceUnavailable
        case configurationFailed(String)
        case sessionInterrupted

        var errorDescription: String? {
            switch self {
            case .permissionDenied:            return "Camera or microphone permission denied."
            case .deviceUnavailable:           return "No suitable camera found on this device."
            case .configurationFailed(let m):  return "Camera configuration failed: \(m)"
            case .sessionInterrupted:          return "Camera session was interrupted."
            }
        }
    }

    // MARK: - Setup

    func requestPermissionsAndConfigure() async {
        let cameraGranted = await AVCaptureDevice.requestAccess(for: .video)
        let audioGranted  = await AVCaptureDevice.requestAccess(for: .audio)

        guard cameraGranted && audioGranted else {
            permissionStatus = .denied
            error = .permissionDenied
            return
        }
        permissionStatus = .authorized
        await configureSession()
    }

    private func configureSession() async {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                self?.buildSession()
                continuation.resume()
            }
        }
    }

    private func buildSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = qualityPreset

        // Remove existing I/O
        session.inputs.forEach  { session.removeInput($0)  }
        session.outputs.forEach { session.removeOutput($0) }

        // ── Video input ──────────────────────────────────────────────────────
        guard
            let videoDevice = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: currentCameraPosition),
            let videoInput  = try? AVCaptureDeviceInput(device: videoDevice),
            session.canAddInput(videoInput)
        else {
            DispatchQueue.main.async { self.error = .deviceUnavailable }
            return
        }
        session.addInput(videoInput)

        // ── Audio input ──────────────────────────────────────────────────────
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput  = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        // ── Video data output ────────────────────────────────────────────────
        videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        ]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        }

        // ── Audio data output ────────────────────────────────────────────────
        audioDataOutput = AVCaptureAudioDataOutput()
        if session.canAddOutput(audioDataOutput) {
            session.addOutput(audioDataOutput)
        }

        // Re-attach any previously set delegate
        if let delegate = videoDelegate {
            videoDataOutput.setSampleBufferDelegate(delegate, queue: videoDataQueue)
            audioDataOutput.setSampleBufferDelegate(delegate, queue: audioDataQueue)
        }

        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playAndRecord,
                mode: .videoRecording,
                options: [.mixWithOthers, .defaultToSpeaker]
            )
            try audioSession.setActive(true)
        } catch {
            print("[CameraSessionManager] Audio session error: \(error)")
        }
    }

    // MARK: - Start / Stop

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async { self.isSessionRunning = true }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async { self.isSessionRunning = false }
        }
    }

    // MARK: - Delegate wiring

    /// Called by RollingRecorder once it is ready to receive sample buffers.
    func setSampleBufferDelegate<T>(
        _ delegate: T
    ) where T: AVCaptureVideoDataOutputSampleBufferDelegate & AVCaptureAudioDataOutputSampleBufferDelegate {
        videoDelegate = delegate
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.videoDataOutput.setSampleBufferDelegate(delegate, queue: self.videoDataQueue)
            self.audioDataOutput.setSampleBufferDelegate(delegate, queue: self.audioDataQueue)
        }
    }

    // MARK: - Orientation

    /// Returns the CGAffineTransform to embed in the AVAssetWriterInput so that
    /// the recorded video displays right-side-up. Must be called on the main thread
    /// before opening a new segment writer.
    @MainActor
    func currentVideoTransform() -> CGAffineTransform {
        switch UIDevice.current.orientation {
        case .landscapeLeft:       return CGAffineTransform(rotationAngle: .pi)
        case .landscapeRight:      return .identity
        case .portraitUpsideDown:  return CGAffineTransform(rotationAngle: -.pi / 2)
        default:                   return CGAffineTransform(rotationAngle: .pi / 2) // portrait
        }
    }

    // MARK: - Camera switching

    func switchCamera() async {
        let wasRunning = session.isRunning
        stopSession()
        currentCameraPosition = currentCameraPosition == .back ? .front : .back
        await configureSession()
        if wasRunning { startSession() }
    }
}
