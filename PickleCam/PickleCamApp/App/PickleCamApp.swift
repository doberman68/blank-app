import SwiftUI
import UserNotifications

@main
struct PickleCamApp: App {

    @StateObject private var store = RecordingSessionStore()

    init() {
        requestNotificationPermission()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - RootView
// ─────────────────────────────────────────────────────────────────────────────

/// State-driven root that swaps screens based on RecordingSessionStore.sessionState.
struct RootView: View {
    @EnvironmentObject var store: RecordingSessionStore

    var body: some View {
        ZStack {
            switch store.sessionState {
            case .idle:
                SetupView()
                    .transition(.opacity)

            case .preparing:
                ProgressView("Preparing camera…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .transition(.opacity)

            case .recording, .savingMoment:
                LiveRecordingView()
                    .transition(.opacity)

            case .exporting:
                if let marker = store.moments.last {
                    ExportView(marker: marker)
                        .transition(.opacity)
                }

            case .error(let message):
                ErrorScreenView(message: message)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.sessionState)
        .preferredColorScheme(.dark)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ErrorScreenView
// ─────────────────────────────────────────────────────────────────────────────

struct ErrorScreenView: View {
    let message: String
    @EnvironmentObject var store: RecordingSessionStore

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.red)
            Text("Something went wrong")
                .font(.title2.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Dismiss") {
                store.dismissError()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
