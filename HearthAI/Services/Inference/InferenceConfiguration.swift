import Foundation

struct InferenceConfiguration {
    var maxTokens: Int32
    var temperature: Float
    var topP: Float
    var repeatPenalty: Float

    static let `default` = InferenceConfiguration(
        maxTokens: 512,
        temperature: 0.7,
        topP: 0.9,
        repeatPenalty: 1.1
    )
}
