import Foundation
import Combine
import WatchKit

/// Drives the watch's main button UI.
/// Translates WatchSessionManager state into display-ready values
/// and fires haptics on send/error.
@MainActor
final class MomentButtonViewModel: ObservableObject {

    // MARK: - Inputs (set in the view)
    var windowMinutes: Int = 30

    // MARK: - Outputs
    @Published private(set) var buttonLabel:     String = "Save Last Point"
    @Published private(set) var statusText:      String = "Connecting…"
    @Published private(set) var lastSentText:    String = ""
    @Published private(set) var isButtonEnabled: Bool   = false
    @Published private(set) var buttonColor:     UIColor = .systemBlue

    // MARK: - Private
    private let sessionManager: WatchSessionManager
    private var cancellables: Set<AnyCancellable> = []

    init(sessionManager: WatchSessionManager) {
        self.sessionManager = sessionManager
        observe()
    }

    // MARK: - Actions

    func didTapButton() {
        sessionManager.sendSaveMoment(windowMinutes: windowMinutes)
        WKInterfaceDevice.current().play(.success)
    }

    // MARK: - State observation

    private func observe() {
        sessionManager.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateDisplay(state: state)
            }
            .store(in: &cancellables)

        sessionManager.$lastSentAt
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] date in
                let f = DateFormatter()
                f.timeStyle = .short
                self?.lastSentText = "Sent \(f.string(from: date))"
            }
            .store(in: &cancellables)
    }

    private func updateDisplay(state: WatchSessionManager.ConnectionState) {
        statusText = state.displayText
        switch state {
        case .ready:
            isButtonEnabled = true
            buttonColor     = .systemBlue
        case .sent:
            isButtonEnabled = true
            buttonColor     = .systemGreen
            WKInterfaceDevice.current().play(.notification)
        case .failed:
            isButtonEnabled = false
            buttonColor     = .systemRed
            WKInterfaceDevice.current().play(.failure)
        case .disconnected, .activating:
            isButtonEnabled = false
            buttonColor     = .systemGray
        }
    }
}
