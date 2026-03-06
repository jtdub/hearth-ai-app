import Foundation
import Network

@Observable
final class NetworkMonitor {
    private(set) var isOnWiFi = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ai.hearth.network-monitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnWiFi = path.usesInterfaceType(.wifi)
                    || path.usesInterfaceType(.wiredEthernet)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
