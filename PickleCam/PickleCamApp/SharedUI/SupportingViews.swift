import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - RecordingIndicatorView
// ─────────────────────────────────────────────────────────────────────────────

/// Pulsing red dot + "REC" label shown in the Live Recording screen.
struct RecordingIndicatorView: View {
    let isRecording: Bool
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isRecording ? Color.red : Color.gray)
                .frame(width: 10, height: 10)
                .scaleEffect(pulsing ? 1.3 : 1.0)
                .animation(
                    isRecording
                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : .default,
                    value: pulsing
                )
            Text(isRecording ? "REC" : "STOPPED")
                .font(.caption.weight(.bold))
                .foregroundStyle(isRecording ? .red : .gray)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .onAppear  { pulsing = isRecording }
        .onChange(of: isRecording) { _, new in pulsing = new }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - StorageIndicatorView
// ─────────────────────────────────────────────────────────────────────────────

struct StorageIndicatorView: View {
    let available: Int64
    let isLow:     Bool

    var body: some View {
        Label(
            ByteCountFormatter.string(fromByteCount: available, countStyle: .file),
            systemImage: isLow ? "internaldrive.fill" : "internaldrive"
        )
        .font(.caption.weight(.semibold))
        .foregroundStyle(isLow ? .orange : .white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ElapsedTimeView
// ─────────────────────────────────────────────────────────────────────────────

struct ElapsedTimeView: View {
    let seconds: Int

    private var formatted: String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    var body: some View {
        Text(formatted)
            .font(.system(.title3, design: .monospaced).weight(.semibold))
            .foregroundStyle(.white)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - WatchTriggerBanner
// ─────────────────────────────────────────────────────────────────────────────

/// Small banner that fades in when the watch fires a save command.
struct WatchTriggerBanner: View {
    let triggeredAt: Date

    private var timeString: String {
        let f = DateFormatter()
        f.timeStyle = .medium
        return f.string(from: triggeredAt)
    }

    var body: some View {
        HStack {
            Image(systemName: "applewatch")
            Text("Watch saved at \(timeString)")
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.85), in: Capsule())
        .foregroundStyle(.white)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - MomentSavedToast
// ─────────────────────────────────────────────────────────────────────────────

struct MomentSavedToast: View {
    var body: some View {
        VStack {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Moment saved!")
                    .font(.subheadline.weight(.semibold))
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.top, 60)
            Spacer()
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - LowStorageWarning
// ─────────────────────────────────────────────────────────────────────────────

struct LowStorageWarningBanner: View {
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Storage low — oldest clips may be removed.")
                .font(.caption.weight(.semibold))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.15))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Previews
// ─────────────────────────────────────────────────────────────────────────────

#Preview("Recording indicator") {
    HStack(spacing: 20) {
        RecordingIndicatorView(isRecording: true)
        RecordingIndicatorView(isRecording: false)
    }
    .padding()
    .background(Color.black)
}

#Preview("Storage indicator") {
    VStack(spacing: 16) {
        StorageIndicatorView(available: 4_000_000_000, isLow: false)
        StorageIndicatorView(available: 300_000_000,   isLow: true)
    }
    .padding()
    .background(Color.black)
}
