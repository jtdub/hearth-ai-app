import Foundation
import Network

@MainActor
@Observable
final class NetworkMonitor {
    private(set) var isCellular = false
    private(set) var isConnected = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ai.hearth.networkMonitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isConnected = path.status == .satisfied
                self.isCellular = path.usesInterfaceType(.cellular)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    /// Returns true if the file size exceeds the cellular warning threshold (200 MB)
    func shouldWarnForCellular(fileSize: Int64) -> Bool {
        isCellular && fileSize > 200 * 1024 * 1024
    }
}
