import SwiftUI

@main
struct PickleCamWatchApp: App {

    @StateObject private var sessionManager = WatchSessionManager()

    var body: some Scene {
        WindowGroup {
            MainButtonView()
                .environmentObject(sessionManager)
        }
    }
}
