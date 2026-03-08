import AppIntents

struct AskHearthIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask Hearth AI"
    static var description = IntentDescription(
        "Ask a question to a local AI model running on your device."
    )

    @Parameter(title: "Question")
    var question: String

    @Parameter(title: "Model")
    var model: LocalModelEntity?

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let result = try await IntentInferenceHelper.run(
            prompt: question,
            systemPrompt: "You are a helpful assistant. Answer concisely.",
            modelId: model?.id
        )
        return .result(value: result.text)
    }
}
