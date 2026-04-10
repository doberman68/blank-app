import SwiftUI

struct SetupView: View {
    @EnvironmentObject var store: RecordingSessionStore
    @StateObject private var vm = SetupViewModel()

    var body: some View {
        NavigationStack {
            Form {
                cameraSection
                rollingWindowSection
                storageEstimateSection
                startSection
            }
            .navigationTitle("PickleCam")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .onAppear { store.storageManager.refresh() }
        }
    }

    // MARK: - Sections

    private var cameraSection: some View {
        Section("Camera") {
            Picker("Lens", selection: $vm.cameraPosition) {
                Text("Back (Wide)").tag(RecordingSession.CameraPosition.back)
                Text("Front").tag(RecordingSession.CameraPosition.front)
            }
            .pickerStyle(.segmented)

            Picker("Quality", selection: $vm.resolutionPreset) {
                ForEach(RecordingSession.ResolutionPreset.allCases, id: \.self) { p in
                    Text(p.displayName).tag(p)
                }
            }
        }
    }

    private var rollingWindowSection: some View {
        Section {
            Picker("Save window", selection: $vm.rollingWindowMinutes) {
                Text("15 min").tag(15)
                Text("30 min").tag(30)
                Text("60 min").tag(60)
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Rolling window")
        } footer: {
            Text("When you tap Save, this is how far back the clip will reach.")
        }
    }

    private var storageEstimateSection: some View {
        Section("Storage") {
            HStack {
                Label("Estimated need", systemImage: "internaldrive")
                Spacer()
                Text(estimatedStorage)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Label("Free on device", systemImage: "checkmark.circle")
                Spacer()
                Text(freeStorage)
                    .foregroundStyle(store.storageManager.isLowStorage ? .orange : .secondary)
            }
            if store.storageManager.isLowStorage {
                Label("Storage is low — free up space before recording.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
    }

    private var startSection: some View {
        Section {
            Button(action: startGame) {
                Label("Start Game", systemImage: "record.circle.fill")
                    .frame(maxWidth: .infinity)
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .listRowBackground(Color.clear)
            .disabled(store.storageManager.isLowStorage)
        }
    }

    // MARK: - Helpers

    private var estimatedStorage: String {
        let bytes = store.storageManager.estimatedStorageBytes(
            minutes: vm.rollingWindowMinutes,
            bitrateMbps: vm.resolutionPreset.approximateBitrateMbps
        )
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private var freeStorage: String {
        ByteCountFormatter.string(
            fromByteCount: store.storageManager.availableBytes,
            countStyle: .file
        )
    }

    private func startGame() {
        Task {
            await store.prepareSession(
                rollingWindowMinutes: vm.rollingWindowMinutes,
                segmentLength:        vm.segmentLengthSeconds,
                cameraPosition:       vm.cameraPosition,
                resolutionPreset:     vm.resolutionPreset
            )
            store.startRecording()
        }
    }
}
