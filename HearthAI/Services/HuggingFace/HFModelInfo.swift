import Foundation

struct HFModelInfo: Codable, Identifiable, Sendable {
    let id: String
    let author: String?
    let downloads: Int
    let likes: Int
    let tags: [String]
    let isPrivate: Bool
    let isGated: Bool?
    let lastModified: String?

    enum CodingKeys: String, CodingKey {
        case id
        case author
        case downloads
        case likes
        case tags
        case isPrivate = "private"
        case isGated = "gated"
        case lastModified
    }

    var displayName: String {
        id.components(separatedBy: "/").last ?? id
    }

    var modelFamily: String {
        let name = displayName.lowercased()
        let families = ["llama", "mistral", "phi", "qwen", "gemma", "smollm", "tinyllama"]
        return families.first { name.contains($0) }?.capitalized ?? "Unknown"
    }
}

struct HFFileInfo: Codable, Identifiable, Sendable {
    let type: String
    let path: String
    let size: Int64?

    var id: String { path }

    var fileName: String {
        path.components(separatedBy: "/").last ?? path
    }

    var isGGUF: Bool {
        fileName.hasSuffix(".gguf")
    }

    var quantization: String {
        let name = fileName.lowercased()
        let quants = [
            "q2_k", "q3_k_s", "q3_k_m", "q3_k_l",
            "q4_0", "q4_1", "q4_k_s", "q4_k_m",
            "q5_0", "q5_1", "q5_k_s", "q5_k_m",
            "q6_k", "q8_0", "f16", "f32",
            "iq2_xxs", "iq2_xs", "iq3_xxs", "iq3_xs",
        ]
        return quants.first { name.contains($0) }?.uppercased() ?? "Unknown"
    }

    var formattedSize: String {
        guard let size else { return "Unknown" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
