import SwiftUI

struct SettingsView: View {
    @AppStorage("segmentLengthSeconds")    private var segmentLength:   Double = 120
    @AppStorage("rollingWindowMinutes")    private var rollingWindow:   Int    = 30
    @AppStorage("resolutionPreset")        private var resolutionRaw:   String = RecordingSession.ResolutionPreset.hd1080p.rawValue
    @AppStorage("audioEnabled")            private var audioEnabled:    Bool   = true

    private var resolution: Binding<RecordingSession.ResolutionPreset> {
        Binding(
            get: { RecordingSession.ResolutionPreset(rawValue: resolutionRaw) ?? .hd1080p },
            set: { resolutionRaw = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Section("Recording") {
                Picker("Segment length", selection: $segmentLength) {
                    Text("60 s").tag(60.0)
                    Text("2 min").tag(120.0)
                    Text("5 min").tag(300.0)
                }

                Picker("Save window", selection: $rollingWindow) {
                    Text("15 min").tag(15)
                    Text("30 min").tag(30)
                    Text("60 min").tag(60)
                }

                Picker("Quality", selection: resolution) {
                    ForEach(RecordingSession.ResolutionPreset.allCases, id: \.self) { p in
                        Text(p.displayName).tag(p)
                    }
                }

                Toggle("Record audio", isOn: $audioEnabled)
            }

            Section {
                LabeledContent("Version", value: appVersion)
            } header: {
                Text("About")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}
