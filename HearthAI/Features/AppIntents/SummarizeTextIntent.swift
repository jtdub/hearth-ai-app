import AppIntents

struct SummarizeTextIntent: AppIntent {
    static var title: LocalizedStringResource = "Summarize with Hearth AI"
    static var description = IntentDescription(
        "Summarize text using a local AI model."
    )

    @Parameter(title: "Text to Summarize")
    var text: String

    @Parameter(title: "Model")
    var model: LocalModelEntity?

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let result = try await IntentInferenceHelper.run(
            prompt: text,
            systemPrompt: "Summarize the following text concisely. "
                + "Output only the summary.",
            modelId: model?.id
        )
        return .result(value: result.text)
    }
}
