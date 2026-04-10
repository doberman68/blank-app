import AVFoundation
import Photos
import Foundation
import Combine

/// Assembles a list of VideoSegments into a single exportable clip using
/// AVMutableComposition + AVAssetExportSession, then saves it to Photos or Files.
@MainActor
final class ExportService: ObservableObject {

    // MARK: - State

    @Published private(set) var isExporting    = false
    @Published private(set) var exportProgress: Double = 0
    @Published private(set) var lastExportedClip: ExportedClip?
    @Published private(set) var exportError:    ExportError?

    private var activeExportSession: AVAssetExportSession?
    private var progressTask:        Task<Void, Never>?

    // MARK: - Errors

    enum ExportError: LocalizedError {
        case noSegments
        case compositionFailed
        case sessionCreationFailed
        case exportFailed(String)
        case photoLibraryDenied

        var errorDescription: String? {
            switch self {
            case .noSegments:             return "No video segments to export."
            case .compositionFailed:      return "Could not assemble video composition."
            case .sessionCreationFailed:  return "Could not create export session."
            case .exportFailed(let msg):  return "Export failed: \(msg)"
            case .photoLibraryDenied:     return "Photo Library permission denied."
            }
        }
    }

    // MARK: - Destination

    enum Destination {
        case photoLibrary
        case files           // clip stays in app's Documents/Exports – visible via Files app
    }

    // MARK: - Public

    func export(
        marker:      MomentMarker,
        segments:    [VideoSegment],
        to dest:     Destination
    ) async throws -> ExportedClip {
        guard !segments.isEmpty else { throw ExportError.noSegments }

        isExporting    = true
        exportProgress = 0
        exportError    = nil
        defer { isExporting = false }

        let ordered = segments.sorted { $0.startedAt < $1.startedAt }

        // ── Build AVMutableComposition ───────────────────────────────────────
        let composition = AVMutableComposition()
        guard
            let videoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ),
            let audioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        else { throw ExportError.compositionFailed }

        var cursor = CMTime.zero

        for seg in ordered {
            let asset    = AVURLAsset(url: seg.fileURL)
            let duration = try await asset.load(.duration)
            let range    = CMTimeRange(start: .zero, duration: duration)

            if let srcVideo = try await asset.loadTracks(withMediaType: .video).first {
                try videoTrack.insertTimeRange(range, of: srcVideo, at: cursor)
            }
            if let srcAudio = try await asset.loadTracks(withMediaType: .audio).first {
                try audioTrack.insertTimeRange(range, of: srcAudio, at: cursor)
            }
            cursor = CMTimeAdd(cursor, duration)
        }

        // ── Configure export session ─────────────────────────────────────────
        let outputURL = outputFileURL(for: marker)
        try? FileManager.default.removeItem(at: outputURL)

        guard let session = AVAssetExportSession(
            asset:      composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else { throw ExportError.sessionCreationFailed }

        session.outputURL                  = outputURL
        session.outputFileType             = .mp4
        session.shouldOptimizeForNetworkUse = true
        activeExportSession                = session

        // Progress polling
        progressTask = Task {
            while !Task.isCancelled {
                exportProgress = Double(session.progress)
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }

        await session.export()
        progressTask?.cancel()

        guard session.status == .completed else {
            throw ExportError.exportFailed(
                session.error?.localizedDescription ?? "Unknown error"
            )
        }

        // ── Save to destination ───────────────────────────────────────────────
        if dest == .photoLibrary {
            try await saveToPhotoLibrary(url: outputURL)
        }

        let size = (
            try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size]
        ) as? Int64 ?? 0

        let clip = ExportedClip(
            id:            UUID(),
            sessionId:     marker.sessionId,
            markerId:      marker.id,
            fileURL:       outputURL,
            startedAt:     ordered.first!.startedAt,
            endedAt:       ordered.last!.endedAt ?? marker.triggeredAt,
            duration:      cursor.seconds,
            fileSizeBytes: size,
            exportedAt:    Date()
        )

        exportProgress    = 1.0
        lastExportedClip  = clip
        return clip
    }

    func cancelExport() {
        progressTask?.cancel()
        activeExportSession?.cancelExport()
    }

    // MARK: - Private

    private func saveToPhotoLibrary(url: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw ExportError.photoLibraryDenied
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
    }

    private func outputFileURL(for marker: MomentMarker) -> URL {
        let dir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Exports", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let ts = Int(marker.triggeredAt.timeIntervalSince1970)
        return dir.appendingPathComponent("clip_\(ts).mp4")
    }
}
