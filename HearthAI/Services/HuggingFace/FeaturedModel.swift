import Foundation

struct FeaturedModel: Codable, Identifiable {
    let repoId: String
    let fileName: String
    let displayName: String
    let modelFamily: String
    let quantization: String
    let sizeBytes: Int64
    let description: String

    var id: String { "\(repoId)/\(fileName)" }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    static func loadFeatured() -> [FeaturedModel] {
        guard let url = Bundle.main.url(forResource: "FeaturedModels", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let models = try? JSONDecoder().decode([FeaturedModel].self, from: data) else {
            return []
        }
        return models
    }
}
