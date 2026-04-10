import WatchConnectivity
import Foundation
import Combine

/// Activates WCSession on watchOS and sends the save-moment command to the phone.
///
/// Message flow:
///   1. Try `sendMessage` (both devices awake, phone reachable).
///   2. Fall back to `transferUserInfo` if the phone is not immediately reachable
///      so the command is queued and delivered when connectivity is restored.
final class WatchSessionManager: NSObject, ObservableObject {

    // MARK: - Published state

    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var lastSentAt:       Date?
    @Published private(set) var lastError:        String?

    // MARK: - Connection state

    enum ConnectionState: Equatable {
        case disconnected
        case activating
        case ready
        case sent
        case failed(String)

        var displayText: String {
            switch self {
            case .disconnected:     return "Not connected"
            case .activating:       return "Connecting…"
            case .ready:            return "Connected"
            case .sent:             return "Sent!"
            case .failed(let msg):  return "Error: \(msg)"
            }
        }

        var isReady: Bool { self == .ready || self == .sent }
    }

    // MARK: - Init

    override init() {
        super.init()
        // Activate early — do NOT wait for the button tap.
        guard WCSession.isSupported() else {
            connectionState = .disconnected
            return
        }
        connectionState = .activating
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Send command

    /// Sends "saveMoment" with the given window size.
    /// Uses `sendMessage` when the phone is reachable, `transferUserInfo` otherwise.
    func sendSaveMoment(windowMinutes: Int = 30) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated
        else {
            connectionState = .failed("WCSession not activated.")
            return
        }

        let payload: [String: Any] = [
            "type":          WatchCommandKey.saveMoment,
            "windowMinutes": windowMinutes
        ]

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.connectionState = .sent
                    self?.lastSentAt      = Date()
                    self?.lastError       = nil
                }
            }, errorHandler: { [weak self] error in
                // Reachable send failed — fall back to queued transfer.
                self?.fallbackTransfer(payload: payload)
            })
        } else {
            fallbackTransfer(payload: payload)
        }
    }

    // MARK: - Private

    private func fallbackTransfer(payload: [String: Any]) {
        WCSession.default.transferUserInfo(payload)
        DispatchQueue.main.async {
            self.connectionState = .sent
            self.lastSentAt      = Date()
            self.lastError       = nil
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {

    func session(
        _ session:                WCSession,
        activationDidCompleteWith state: WCSessionActivationState,
        error:                    Error?
    ) {
        DispatchQueue.main.async {
            if let error {
                self.connectionState = .failed(error.localizedDescription)
                self.lastError       = error.localizedDescription
            } else {
                self.connectionState = session.isReachable ? .ready : .disconnected
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            if session.isReachable {
                if self.connectionState == .disconnected || self.connectionState == .activating {
                    self.connectionState = .ready
                }
            } else {
                if self.connectionState == .ready {
                    self.connectionState = .disconnected
                }
            }
        }
    }

    // Receive optional status replies from phone
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        // Phone can send {"status": "recording"} etc. — extend as needed.
    }
}

// MARK: - Shared message key constant

enum WatchCommandKey {
    static let saveMoment = "saveMoment"
}
