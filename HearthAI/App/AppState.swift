import SwiftUI

/// Central app state that owns shared services.
@Observable
final class AppState {
    let inferenceService = InferenceService()
    let thermalMonitor = ThermalMonitor()
    let downloadService = DownloadService()
    let networkMonitor = NetworkMonitor()
}
