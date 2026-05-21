# Pickleball Dashcam (iPhone + Apple Watch) — Implementation Blueprint

## Goal
Build an iOS + watchOS app where:
- iPhone is mounted courtside and continuously buffers video/audio.
- Player taps a red button on Apple Watch during a rally/event.
- App saves a clip containing the **previous 30, 45, or 60 seconds** (pre-event footage), like a car dashcam.

---

## Product Architecture

### Components
1. **iPhone app (primary capture + clip export)**
   - Captures camera + microphone using `AVCaptureSession`.
   - Continuously writes short rolling segments (e.g., 1-second chunks).
   - Maintains a ring buffer index of recent segments.
   - On trigger, concatenates the required lookback window and saves to Photos/app storage.

2. **Apple Watch app (remote trigger)**
   - Big red “Save Clip” button.
   - Optional clip length picker: 30 / 45 / 60 seconds.
   - Sends trigger instantly via `WatchConnectivity`.

3. **Connectivity channel**
   - Use `WCSession` message transport (`sendMessage`) when reachable.
   - Fallback to `transferUserInfo` when the phone is temporarily unreachable.

---

## Why segment-based rolling buffer is the safest approach

Instead of trying to “rewind” a live camera stream in memory, use segmented recording:
- Record fixed-duration files (1 sec is ideal for precise clipping).
- Keep only last N seconds in ring buffer metadata.
- Delete old files as new ones arrive.

This is reliable, battery-friendly, and resilient to memory pressure.

---

## Core iPhone pipeline

### 1) Camera capture
- `AVCaptureSession`
- `AVCaptureVideoDataOutput` + `AVCaptureAudioDataOutput` **or** `AVCaptureMovieFileOutput` with custom segmenting logic.
- Prefer `AVAssetWriter` for full control of segment boundaries.

### 2) Rolling segment writer
- Write files to: `Application Support/RollingBuffer/`.
- Segment duration: `1.0s` (or `2.0s` if you need less file churn).
- Naming convention: `seg_<monotonicTimestamp>.mp4`.
- Store metadata in memory + lightweight index file:
  - `startTime`
  - `endTime`
  - `url`
  - `duration`

### 3) Buffer policy
- Keep maximum of ~75 seconds locally to support 60s clip + trigger latency margin.
- As each new segment completes:
  - append to ring
  - trim oldest segments beyond retention window
  - delete trimmed files from disk

### 4) Trigger handling
When watch sends `save_clip` with `duration = 30|45|60`:
1. Determine trigger timestamp `T`.
2. Compute desired interval `[T - duration, T]`.
3. Collect overlapping segment URLs.
4. Build composition with `AVMutableComposition`.
5. Export `.mp4` using `AVAssetExportSession`.
6. Save output to:
   - Photo Library (`PHPhotoLibrary`) and/or
   - App clips list (for share/export)

### 5) Optional post-trigger padding
If you want “a little after the button press”:
- save `[T - duration, T + 2s]`
- or support presets: `pre-only` vs `pre+post`

---

## Watch app UX

### Required controls
- **Red button**: “Save Last Clip”.
- Segmented picker: `30s / 45s / 60s`.
- Status text:
  - “Phone connected” / “Phone unreachable”
  - “Clip request sent”
  - Last clip success/failure

### Latency notes
- `sendMessage` is best for immediate action while app is active/reachable.
- Always queue fallback with `transferUserInfo` so tap is not lost.

---

## Data model

```swift
struct SegmentMeta: Codable, Identifiable {
    let id: UUID
    let url: URL
    let start: CMTime
    let end: CMTime
    var duration: CMTime { end - start }
}

struct ClipRequest: Codable {
    let requestedAt: Date
    let lookbackSeconds: Int // 30, 45, 60
    let source: String // "watch" | "phone"
}
```

---

## Minimal Swift skeleton (phone side)

```swift
final class RollingBufferController {
    private var segments: [SegmentMeta] = []
    private let retention: TimeInterval = 75

    func onSegmentFinished(_ seg: SegmentMeta) {
        segments.append(seg)
        trimOldSegments(reference: seg.end)
    }

    private func trimOldSegments(reference: CMTime) {
        let minStart = reference.seconds - retention
        while let first = segments.first, first.end.seconds < minStart {
            try? FileManager.default.removeItem(at: first.url)
            segments.removeFirst()
        }
    }

    func segmentURLs(forLookback seconds: Int, now: CMTime) -> [URL] {
        let start = now.seconds - Double(seconds)
        return segments
            .filter { $0.end.seconds >= start && $0.start.seconds <= now.seconds }
            .map(\.url)
    }
}
```

---

## Export flow pseudocode

```swift
func exportClip(lookback: Int, now: CMTime) async throws -> URL {
    let urls = buffer.segmentURLs(forLookback: lookback, now: now)
    guard !urls.isEmpty else { throw ClipError.noSegments }

    let composition = AVMutableComposition()
    // Append all assets sequentially, trim boundaries to exact interval if desired.

    let outputURL = clipsDirectory
        .appendingPathComponent("clip_\(Date().timeIntervalSince1970).mp4")

    // AVAssetExportSession(...) -> outputURL
    return outputURL
}
```

---

## Permissions & background behavior

### iPhone permissions
- Camera (`NSCameraUsageDescription`)
- Microphone (`NSMicrophoneUsageDescription`)
- Photo Library add (`NSPhotoLibraryAddUsageDescription`) if saving to Photos

### Background constraints (important)
- Continuous camera capture is generally foreground-centric on iOS.
- Expect best reliability when phone app stays active on-screen while mounted.
- Guide users with a “recording active” screen and disable Auto-Lock during sessions.

---

## Performance targets
- 1080p @ 30fps is usually enough for pickleball review.
- Use H.264 first for compatibility; HEVC optional.
- Keep segment durations short (1s) for precise extraction.
- Monitor thermal state and downshift resolution if device overheats.

---

## MVP roadmap (4 phases)

1. **Phone-only MVP**
   - Rolling 60s buffer
   - On-phone trigger button
   - Save last 30/45/60s clip

2. **Watch trigger integration**
   - `WCSession` messaging
   - Red watch button + duration selector

3. **Clip gallery + share**
   - List exported clips
   - AirDrop / share sheet

4. **Polish**
   - Haptic confirmation on watch
   - Event marker overlay
   - Optional auto-highlights later (ML)

---

## Testing checklist

### Functional
- Trigger at random times; verify exported clip starts exactly N seconds before trigger.
- Test all durations (30/45/60).
- Trigger repeatedly (debounce and queue behavior).

### Failure modes
- Watch disconnected mid-game.
- Low storage conditions.
- App interruption (phone lock, incoming call).

### Field test
- 60+ minute session on court.
- Validate thermal and battery behavior.
- Confirm segment cleanup leaves no orphan files.

---

## Risks and mitigations
- **Latency from watch to phone** → keep +10–15s retention margin beyond max lookback.
- **Thermal throttling** → adaptive bitrate/resolution.
- **Dropped frames** → avoid heavy UI while recording; isolate writer queue.
- **Storage growth** → strict rolling delete + periodic integrity cleanup.

---

## Suggested next step
Start with the **Phone-only MVP** first. Once segmented rolling buffer + export is stable, add watch trigger as a thin remote-control layer.
