import AppIntents

struct RewriteTextIntent: AppIntent {
    static var title: LocalizedStringResource = "Rewrite with Hearth AI"
    static var description = IntentDescription(
        "Rewrite text in a different style using a local AI model."
    )

    @Parameter(title: "Text to Rewrite")
    var text: String

    @Parameter(title: "Style")
    var style: RewriteStyle

    @Parameter(title: "Model")
    var model: LocalModelEntity?

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let result = try await IntentInferenceHelper.run(
            prompt: text,
            systemPrompt: "Rewrite the following text in a "
                + "\(style.rawValue) tone. "
                + "Output only the rewritten text.",
            modelId: model?.id
        )
        return .result(value: result.text)
    }
}

enum RewriteStyle: String, AppEnum {
    case formal
    case casual
    case concise
    case detailed
    case friendly
    case professional

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Writing Style"
    }

    static var caseDisplayRepresentations: [RewriteStyle: DisplayRepresentation] {
        [
            .formal: "Formal",
            .casual: "Casual",
            .concise: "Concise",
            .detailed: "Detailed",
            .friendly: "Friendly",
            .professional: "Professional",
        ]
    }
}
