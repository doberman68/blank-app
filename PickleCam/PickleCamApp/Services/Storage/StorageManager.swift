import Foundation
import Combine

/// Monitors device free space and enforces the rolling-window purge policy.
@MainActor
final class StorageManager: ObservableObject {

    /// Keep at least 500 MB free at all times.
    static let minimumFreeSpaceBytes: Int64 = 500 * 1024 * 1024

    @Published private(set) var availableBytes: Int64 = 0
    @Published private(set) var usedByAppBytes:  Int64 = 0
    @Published private(set) var isLowStorage: Bool = false

    private var refreshTimer: Timer?

    // MARK: - Monitoring lifecycle

    func startMonitoring() {
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stopMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func refresh() {
        availableBytes = freeSpaceBytes()
        usedByAppBytes  = appDocumentsBytes()
        isLowStorage   = availableBytes < Self.minimumFreeSpaceBytes
    }

    // MARK: - Estimate

    /// Approximate bytes required to store `minutes` of video at the given bitrate.
    func estimatedStorageBytes(minutes: Int, bitrateMbps: Double = 8) -> Int64 {
        let bytesPerSecond = Int64(bitrateMbps * 1_000_000 / 8)
        return bytesPerSecond * Int64(minutes * 60)
    }

    var estimatedStorageFormatted: (minutes: Int, bytes: Int64, humanReadable: String) {
        let bytes = estimatedStorageBytes(minutes: 30)
        let human = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        return (30, bytes, human)
    }

    // MARK: - Purge

    /// Deletes oldest unprotected & finalized segments until the rolling window is respected
    /// and storage is no longer critically low.
    func purgeExpiredSegments(
        sessionId: UUID,
        windowMinutes: Int,
        store: SegmentIndexStore
    ) async {
        let cutoff = Calendar.current.date(
            byAdding: .minute, value: -windowMinutes, to: Date()
        ) ?? Date()

        // Time-based expiry
        let expired = store.unprotectedSegments(for: sessionId)
            .filter { seg in
                guard let end = seg.endedAt else { return false }
                return end < cutoff
            }
        for seg in expired { store.delete(segmentId: seg.id) }

        // Storage-pressure purge (oldest first)
        refresh()
        if isLowStorage {
            let remaining = store.unprotectedSegments(for: sessionId)
            for seg in remaining {
                guard isLowStorage else { break }
                store.delete(segmentId: seg.id)
                refresh()
            }
        }
    }

    // MARK: - Private helpers

    private func freeSpaceBytes() -> Int64 {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let values = try? url.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        )
        return Int64(values?.volumeAvailableCapacityForImportantUsage ?? 0)
    }

    private func appDocumentsBytes() -> Int64 {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return directorySize(url: dir)
    }

    private func directorySize(url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        return enumerator
            .compactMap { $0 as? URL }
            .compactMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize }
            .reduce(0) { $0 + Int64($1) }
    }
}
