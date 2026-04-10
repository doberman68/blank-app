import WatchConnectivity
import Combine
import Foundation

/// Receives commands sent by the Apple Watch over WatchConnectivity
/// and exposes them to the rest of the app via a callback and @Published state.
///
/// Strategy:
///   - Primary path:  `sendMessage` (instant, requires both devices awake)
///   - Fallback path: `transferUserInfo` (queued, arrives when phone is reachable)
final class WatchCommandReceiver: NSObject, ObservableObject {

    // MARK: - Published state

    @Published private(set) var isWatchReachable:  Bool = false
    @Published private(set) var activationState:   WCSessionActivationState = .notActivated
    @Published private(set) var lastCommand:        WatchCommand?

    // MARK: - Callback

    /// Set by RecordingSessionStore. Called on the main thread.
    var onSaveMoment: ((_ windowMinutes: Int) -> Void)?

    // MARK: - Init

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Outbound (optional: send status back to watch)

    func sendStatusToWatch(status: String) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isReachable
        else { return }
        WCSession.default.sendMessage(["status": status], replyHandler: nil)
    }
}

// MARK: - WCSessionDelegate

extension WatchCommandReceiver: WCSessionDelegate {

    func session(
        _ session:             WCSession,
        activationDidCompleteWith state: WCSessionActivationState,
        error:                 Error?
    ) {
        DispatchQueue.main.async {
            self.activationState  = state
            self.isWatchReachable = session.isReachable
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate on paired-watch switch
        WCSession.default.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
    }

    // Immediate message (primary path)
    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        dispatch(message)
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        dispatch(message)
        replyHandler(["ack": "received"])
    }

    // Queued transfer (fallback path)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        dispatch(userInfo)
    }

    // MARK: - Message dispatch

    private func dispatch(_ message: [String: Any]) {
        guard
            let typeRaw = message["type"] as? String,
            let command = WatchCommand(rawValue: typeRaw)
        else { return }

        DispatchQueue.main.async {
            self.lastCommand = command
            switch command {
            case .saveMoment:
                let minutes = message["windowMinutes"] as? Int ?? 30
                self.onSaveMoment?(minutes)
            }
        }
    }
}

// MARK: - Command enum (shared message contract)

enum WatchCommand: String, Sendable {
    case saveMoment = "saveMoment"
}
