import AppIntents

struct TranslateTextIntent: AppIntent {
    static var title: LocalizedStringResource = "Translate with Hearth AI"
    static var description = IntentDescription(
        "Translate text using a local AI model."
    )

    @Parameter(title: "Text to Translate")
    var text: String

    @Parameter(title: "Target Language")
    var targetLanguage: TargetLanguage

    @Parameter(title: "Model")
    var model: LocalModelEntity?

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let result = try await IntentInferenceHelper.run(
            prompt: text,
            systemPrompt: "Translate the following text to "
                + "\(targetLanguage.rawValue). "
                + "Output only the translation.",
            modelId: model?.id
        )
        return .result(value: result.text)
    }
}

enum TargetLanguage: String, AppEnum {
    case english = "English"
    case spanish = "Spanish"
    case french = "French"
    case german = "German"
    case japanese = "Japanese"
    case chinese = "Chinese"
    case korean = "Korean"
    case portuguese = "Portuguese"
    case italian = "Italian"
    case russian = "Russian"
    case arabic = "Arabic"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Language"
    }

    static var caseDisplayRepresentations: [TargetLanguage: DisplayRepresentation] {
        [
            .english: "English",
            .spanish: "Spanish",
            .french: "French",
            .german: "German",
            .japanese: "Japanese",
            .chinese: "Chinese",
            .korean: "Korean",
            .portuguese: "Portuguese",
            .italian: "Italian",
            .russian: "Russian",
            .arabic: "Arabic",
        ]
    }
}
