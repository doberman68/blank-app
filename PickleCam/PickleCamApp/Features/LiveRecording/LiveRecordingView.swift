import SwiftUI

struct LiveRecordingView: View {
    @EnvironmentObject var store: RecordingSessionStore

    @State private var showSavedMoments   = false
    @State private var showStopConfirm    = false
    @State private var showMomentToast    = false
    @State private var momentCount        = 0

    private var windowLabel: String {
        "\(store.currentSession?.rollingWindowMinutes ?? 30) Min"
    }

    var body: some View {
        ZStack {
            // Full-screen camera preview
            CameraPreviewView(session: store.cameraManager.session)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                watchBanner
                bottomControls
            }

            if showMomentToast {
                MomentSavedToast()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }

            if store.storageManager.isLowStorage {
                VStack {
                    Spacer()
                    LowStorageWarningBanner()
                }
            }
        }
        .sheet(isPresented: $showSavedMoments) {
            SavedMomentsView()
        }
        .confirmationDialog(
            "Stop Recording?",
            isPresented: $showStopConfirm,
            titleVisibility: .visible
        ) {
            Button("Stop & Review Moments", role: .destructive) { store.stopRecording() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Recording will stop. Your saved moments remain available to export.")
        }
        .onChange(of: store.moments.count) { old, new in
            guard new > old else { return }
            withAnimation { showMomentToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation { showMomentToast = false }
            }
        }
        .statusBarHidden(true)
    }

    // MARK: - Subviews

    private var topBar: some View {
        HStack {
            RecordingIndicatorView(isRecording: store.sessionState == .recording)
            Spacer()
            ElapsedTimeView(seconds: store.elapsedSeconds)
            Spacer()
            StorageIndicatorView(
                available: store.storageManager.availableBytes,
                isLow:     store.storageManager.isLowStorage
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var watchBanner: some View {
        if let t = store.lastWatchTrigger {
            WatchTriggerBanner(triggeredAt: t)
                .padding(.bottom, 12)
                .transition(.scale.combined(with: .opacity))
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 12) {
            // Primary action: Save moment
            Button(action: { store.saveMoment(source: .phone) }) {
                Label("Save Last \(windowLabel)", systemImage: "bookmark.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            HStack(spacing: 12) {
                // Saved moments list
                Button {
                    showSavedMoments = true
                } label: {
                    Label(
                        "\(store.moments.count) Saved",
                        systemImage: "list.bullet.rectangle.portrait"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.white)

                // Stop game
                Button {
                    showStopConfirm = true
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }
}
