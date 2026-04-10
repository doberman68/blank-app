import SwiftUI

/// The only screen on the watch: a large tap target that sends "save last N min"
/// to the paired iPhone over WatchConnectivity.
struct MainButtonView: View {
    @EnvironmentObject var sessionManager: WatchSessionManager
    @StateObject private var vm: MomentButtonViewModel

    init() {
        // ViewModel is created here; sessionManager injected via EnvironmentObject
        // so we use a placeholder and replace in onAppear.
        _vm = StateObject(wrappedValue: MomentButtonViewModel(
            sessionManager: WatchSessionManager()   // temporary; replaced below
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Status label ─────────────────────────────────────────────────
            Text(sessionManager.connectionState.displayText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(statusColor)
                .padding(.top, 4)

            Spacer()

            // ── Big save button ───────────────────────────────────────────────
            Button(action: sendSave) {
                VStack(spacing: 6) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 28, weight: .bold))
                    Text("Save Last\nPoint")
                        .font(.system(size: 14, weight: .bold))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(BigSaveButtonStyle(
                enabled: sessionManager.connectionState.isReady
            ))
            .disabled(!sessionManager.connectionState.isReady)

            Spacer()

            // ── Last sent confirmation ────────────────────────────────────────
            if let sent = sessionManager.lastSentAt {
                Text("Sent \(sent.formatted(.dateTime.hour().minute().second()))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
            }
        }
        .padding(8)
    }

    // MARK: - Private

    private func sendSave() {
        sessionManager.sendSaveMoment(windowMinutes: 30)
    }

    private var statusColor: Color {
        switch sessionManager.connectionState {
        case .ready, .sent:         return .green
        case .failed:               return .red
        case .disconnected,
             .activating:           return .gray
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - BigSaveButtonStyle
// ─────────────────────────────────────────────────────────────────────────────

struct BigSaveButtonStyle: ButtonStyle {
    let enabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                Circle()
                    .fill(
                        enabled
                            ? (configuration.isPressed ? Color.blue.opacity(0.7) : Color.blue)
                            : Color.gray.opacity(0.4)
                    )
                    .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            )
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Preview
// ─────────────────────────────────────────────────────────────────────────────

#Preview {
    MainButtonView()
        .environmentObject(WatchSessionManager())
}
