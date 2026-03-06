import Foundation

final class HuggingFaceAPI: Sendable {
    // swiftlint:disable:next force_unwrapping
    private let baseURL = URL(string: "https://huggingface.co/api")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchModels(query: String, limit: Int = 20) async throws -> [HFModelInfo] {
        var components = URLComponents(url: baseURL.appendingPathComponent("models"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "filter", value: "gguf"),
            URLQueryItem(name: "sort", value: "downloads"),
            URLQueryItem(name: "direction", value: "-1"),
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        guard let url = components?.url else {
            throw HFAPIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try validateResponse(response)

        let models = try JSONDecoder().decode([HFModelInfo].self, from: data)
        return models.filter { !$0.isPrivate && $0.isGated != true }
    }

    func getModelInfo(repoId: String) async throws -> HFModelInfo {
        let url = baseURL
            .appendingPathComponent("models")
            .appendingPathComponent(repoId)

        let (data, response) = try await session.data(from: url)
        try validateResponse(response)

        return try JSONDecoder().decode(HFModelInfo.self, from: data)
    }

    func listFiles(repoId: String) async throws -> [HFFileInfo] {
        let url = baseURL
            .appendingPathComponent("models")
            .appendingPathComponent(repoId)
            .appendingPathComponent("tree")
            .appendingPathComponent("main")

        let (data, response) = try await session.data(from: url)
        try validateResponse(response)

        let files = try JSONDecoder().decode([HFFileInfo].self, from: data)
        return files.filter { $0.isGGUF }
    }

    func downloadURL(repoId: String, fileName: String) -> URL {
        let encoded = fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fileName
        // swiftlint:disable:next force_unwrapping
        return URL(string: "https://huggingface.co/\(repoId)/resolve/main/\(encoded)")!
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HFAPIError.invalidResponse
        }
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 404:
            throw HFAPIError.notFound
        case 429:
            throw HFAPIError.rateLimited
        default:
            throw HFAPIError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

enum HFAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case notFound
    case rateLimited
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid URL"
        case .invalidResponse:
            "Invalid response from server"
        case .notFound:
            "Model not found"
        case .rateLimited:
            "Rate limited. Please try again later."
        case .httpError(let code):
            "Server error (HTTP \(code))"
        }
    }
}
