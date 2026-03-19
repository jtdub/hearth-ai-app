import Foundation

enum Constants {
    static let defaultContextSize: Int32 = 2048
    static let defaultTemperature: Float = 0.7
    static let defaultTopP: Float = 0.9
    static let defaultRepeatPenalty: Float = 1.1
    static let defaultMaxTokens: Int32 = 512
    static let backgroundUnloadTimeout: TimeInterval = 60
    static let firstTokenTimeoutSeconds: TimeInterval = 120
    static let interTokenTimeoutSeconds: TimeInterval = 30

    // Document processing
    static let defaultChunkSize: Int = 512
    static let defaultChunkOverlap: Int = 50
    static let maxDocumentChunksInPrompt: Int = 3
    static let documentTokenBudgetFraction: Float = 0.6
    static let memoryTokenBudgetFraction: Float = 0.15
}
