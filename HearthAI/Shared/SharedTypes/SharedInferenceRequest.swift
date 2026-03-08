import Foundation

/// A request queued by the Share Extension for the main app to process.
struct SharedInferenceRequest: Codable, Identifiable {
    let id: UUID
    let inputText: String
    let taskType: TaskType
    let modelId: String?
    var status: RequestStatus
    var result: String?

    init(
        inputText: String,
        taskType: TaskType,
        modelId: String? = nil
    ) {
        self.id = UUID()
        self.inputText = inputText
        self.taskType = taskType
        self.modelId = modelId
        self.status = .pending
    }

    enum TaskType: String, Codable, CaseIterable {
        case ask
        case summarize
        case translate
        case rewrite
        case explain

        var displayName: String {
            switch self {
            case .ask: "Ask"
            case .summarize: "Summarize"
            case .translate: "Translate"
            case .rewrite: "Rewrite"
            case .explain: "Explain"
            }
        }

        var systemPrompt: String {
            switch self {
            case .ask:
                "You are a helpful assistant. Answer concisely."
            case .summarize:
                "Summarize the following text concisely. "
                + "Output only the summary."
            case .translate:
                "Translate the following text to English. "
                + "Output only the translation."
            case .rewrite:
                "Rewrite the following text to be clearer "
                + "and more concise. Output only the rewritten text."
            case .explain:
                "Explain the following text in simple terms. "
                + "Be concise."
            }
        }
    }

    enum RequestStatus: String, Codable {
        case pending
        case processing
        case completed
        case failed
    }

    // MARK: - File I/O

    var fileURL: URL? {
        AppGroupConstants.pendingRequestsDirectory?
            .appendingPathComponent("\(id.uuidString).json")
    }

    func save() throws {
        guard let url = fileURL else { return }
        let data = try JSONEncoder().encode(self)
        try data.write(to: url)
    }

    static func load(id: UUID) throws -> SharedInferenceRequest? {
        guard let dir = AppGroupConstants.pendingRequestsDirectory else {
            return nil
        }
        let url = dir.appendingPathComponent("\(id.uuidString).json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SharedInferenceRequest.self, from: data)
    }

    func delete() {
        guard let url = fileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
