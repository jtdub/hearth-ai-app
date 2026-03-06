import Foundation

@Observable
final class ThermalMonitor {
    private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    private(set) var shouldWarnUser = false

    init() {
        thermalState = ProcessInfo.processInfo.thermalState
        updateWarning()

        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.thermalState = ProcessInfo.processInfo.thermalState
            self?.updateWarning()
        }
    }

    var warningMessage: String? {
        switch thermalState {
        case .serious:
            "Your device is getting warm. Consider using a smaller model."
        case .critical:
            "Device is overheating. Generation paused to cool down."
        default:
            nil
        }
    }

    private func updateWarning() {
        shouldWarnUser = thermalState == .serious || thermalState == .critical
    }
}
