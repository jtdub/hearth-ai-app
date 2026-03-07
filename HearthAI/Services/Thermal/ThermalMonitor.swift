import Foundation

@MainActor
@Observable
final class ThermalMonitor {
    private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    private(set) var shouldWarnUser = false
    var onCritical: (() -> Void)?

    private nonisolated(unsafe) var notificationObserver: Any?

    init() {
        thermalState = ProcessInfo.processInfo.thermalState
        updateWarning()

        notificationObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.thermalState = ProcessInfo.processInfo.thermalState
                self?.updateWarning()
            }
        }
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    var isCritical: Bool {
        thermalState == .critical
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
        if thermalState == .critical {
            onCritical?()
        }
    }
}
