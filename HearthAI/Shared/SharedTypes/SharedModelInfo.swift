import Foundation

/// Lightweight model info shared between the main app and extensions.
/// Does not depend on SwiftData.
struct SharedModelInfo: Codable, Identifiable {
    let id: String
    let displayName: String
    let modelFamily: String
    let quantization: String
    let fileSizeBytes: Int64
    let localPath: String

    /// Load available models from the shared container.
    /// Can be called from both the main app and extensions.
    static func loadFromSharedContainer() -> [SharedModelInfo] {
        guard let url = AppGroupConstants.availableModelsURL,
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        return (try? JSONDecoder().decode(
            [SharedModelInfo].self, from: data
        )) ?? []
    }
}
