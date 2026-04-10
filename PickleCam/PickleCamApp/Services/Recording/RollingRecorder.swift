import AVFoundation
import Combine
import UIKit

/// Writes a continuous stream of fixed-length segment files using AVAssetWriter.
/// Conforms to both AVCapture sample-buffer delegate protocols so it can be
/// plugged directly into CameraSessionManager.setSampleBufferDelegate(_:).
final class RollingRecorder: NSObject, ObservableObject {

    // MARK: - Configuration

    struct Configuration {
        var segmentDuration: TimeInterval  = 120       // 2 minutes per segment
        var rollingWindowMinutes: Int       = 30
        var fileType: AVFileType            = .mp4
        var videoSettings: [String: Any]    = [
            AVVideoCodecKey:             AVVideoCodecType.h264,
            AVVideoWidthKey:             1920,
            AVVideoHeightKey:            1080,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey:          8_000_000,
                AVVideoProfileLevelKey:            AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey:     60
            ]
        ]
        var audioSettings: [String: Any]    = [
            AVFormatIDKey:             kAudioFormatMPEG4AAC,
            AVSampleRateKey:           44_100,
            AVNumberOfChannelsKey:     2,
            AVEncoderBitRateKey:       128_000
        ]
    }

    // MARK: - Published state

    @Published private(set) var isRecording = false
    @Published private(set) var segmentsWritten = 0
    @Published private(set) var recordingError: Error?

    // MARK: - Dependencies

    private let segmentStore:   SegmentIndexStore
    private let storageManager: StorageManager
    private var configuration:  Configuration

    // MARK: - Private state

    private var sessionId:          UUID?
    private var videoTransform:     CGAffineTransform = .identity
    private var currentWriter:      AVAssetWriter?
    private var videoInput:         AVAssetWriterInput?
    private var audioInput:         AVAssetWriterInput?
    private var segmentStartDate:   Date = Date()
    private var firstSampleWritten: Bool = false
    private var rotationTimer:      Timer?

    /// Writer operations run on this queue; sample buffers arrive here too.
    private let writerQueue = DispatchQueue(label: "com.picklecam.writer", qos: .userInitiated)

    // MARK: - Init

    init(
        segmentStore:   SegmentIndexStore,
        storageManager: StorageManager,
        configuration:  Configuration = .init()
    ) {
        self.segmentStore   = segmentStore
        self.storageManager = storageManager
        self.configuration  = configuration
    }

    // MARK: - Public API

    func updateConfiguration(_ config: Configuration) {
        configuration = config
        updateVideoSettings(for: config)
    }

    func startRecording(sessionId: UUID, videoTransform: CGAffineTransform) {
        self.sessionId     = sessionId
        self.videoTransform = videoTransform
        isRecording        = true
        openNewSegment()
        scheduleRotation()
    }

    func stopRecording() {
        rotationTimer?.invalidate()
        rotationTimer = nil
        isRecording   = false
        writerQueue.async { [weak self] in self?.closeCurrentSegment() }
    }

    // MARK: - Segment lifecycle

    private func openNewSegment() {
        guard let sessionId else { return }
        let url = newSegmentURL()
        segmentStartDate   = Date()
        firstSampleWritten = false

        do {
            let writer   = try AVAssetWriter(outputURL: url, fileType: configuration.fileType)
            let vInput   = makeVideoInput()
            let aInput   = makeAudioInput()

            if writer.canAdd(vInput) { writer.add(vInput) }
            if writer.canAdd(aInput) { writer.add(aInput) }

            currentWriter = writer
            videoInput    = vInput
            audioInput    = aInput

            // Register with the store (endedAt/duration/size filled in after finalization)
            let segment = VideoSegment(
                id:            UUID(),
                sessionId:     sessionId,
                fileURL:       url,
                startedAt:     segmentStartDate,
                endedAt:       nil,
                duration:      0,
                fileSizeBytes: 0,
                isProtected:   false
            )
            Task { @MainActor [weak self] in
                self?.segmentStore.addSegment(segment)
                self?.segmentsWritten += 1
            }
        } catch {
            DispatchQueue.main.async { self.recordingError = error }
        }
    }

    private func closeCurrentSegment() {
        guard let writer = currentWriter else { return }
        let fileURL  = writer.outputURL
        let endDate  = Date()

        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        writer.finishWriting { [weak self] in
            guard let self else { return }
            let size = (
                try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size]
            ) as? Int64 ?? 0

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.segmentStore.finalizeSegment(
                    fileURL:       fileURL,
                    endedAt:       endDate,
                    fileSizeBytes: size
                )
                if let sid = self.sessionId {
                    await self.storageManager.purgeExpiredSegments(
                        sessionId:     sid,
                        windowMinutes: self.configuration.rollingWindowMinutes,
                        store:         self.segmentStore
                    )
                }
            }
        }

        currentWriter = nil
        videoInput    = nil
        audioInput    = nil
    }

    private func rotate() {
        writerQueue.async { [weak self] in
            guard let self, self.isRecording else { return }
            self.closeCurrentSegment()
            self.openNewSegment()
        }
    }

    private func scheduleRotation() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.rotationTimer = Timer.scheduledTimer(
                withTimeInterval: self.configuration.segmentDuration,
                repeats:          true
            ) { [weak self] _ in self?.rotate() }
        }
    }

    // MARK: - AVAssetWriterInput factory helpers

    private func makeVideoInput() -> AVAssetWriterInput {
        let input = AVAssetWriterInput(
            mediaType:        .video,
            outputSettings:   configuration.videoSettings
        )
        input.expectsMediaDataInRealTime = true
        input.transform                  = videoTransform
        return input
    }

    private func makeAudioInput() -> AVAssetWriterInput {
        let input = AVAssetWriterInput(
            mediaType:       .audio,
            outputSettings:  configuration.audioSettings
        )
        input.expectsMediaDataInRealTime = true
        return input
    }

    private func updateVideoSettings(for config: Configuration) {
        // No-op on the running writer; applies on the next openNewSegment() call.
    }

    // MARK: - File URL generation

    private func newSegmentURL() -> URL {
        let segments = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Segments", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: segments, withIntermediateDirectories: true
        )
        return segments.appendingPathComponent(
            "seg_\(Int(Date().timeIntervalSince1970)).mp4"
        )
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension RollingRecorder: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output:          AVCaptureOutput,
        didOutput buffer:  CMSampleBuffer,
        from connection:   AVCaptureConnection
    ) {
        guard isRecording,
              let writer = currentWriter,
              let vInput = videoInput,
              vInput.isReadyForMoreMediaData
        else { return }

        if !firstSampleWritten {
            let pts = CMSampleBufferGetPresentationTimeStamp(buffer)
            writer.startWriting()
            writer.startSession(atSourceTime: pts)
            firstSampleWritten = true
        }

        if writer.status == .writing {
            vInput.append(buffer)
        }
    }
}

// MARK: - AVCaptureAudioDataOutputSampleBufferDelegate

extension RollingRecorder: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output:         AVCaptureOutput,
        didOutput buffer: CMSampleBuffer,
        from connection:  AVCaptureConnection
    ) {
        guard isRecording,
              let writer = currentWriter,
              let aInput = audioInput,
              aInput.isReadyForMoreMediaData,
              firstSampleWritten,
              writer.status == .writing
        else { return }

        aInput.append(buffer)
    }
}
