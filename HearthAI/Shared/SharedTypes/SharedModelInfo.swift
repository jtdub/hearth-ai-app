import Foundation

/// Lightweight model info that the main app and the extensions
/// share. It does not depend on SwiftData.
struct SharedModelInfo: Codable, Identifiable {
    let id: String
    let displayName: String
    let modelFamily: String
    let quantization: String
    let fileSizeBytes: Int64
    let localPath: String

    /// Load available models from the shared container.
    /// The main app and the extensions can call this function.
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
