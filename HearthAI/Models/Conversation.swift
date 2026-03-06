import Foundation
import SwiftData

@Model
final class Conversation {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var systemPrompt: String
    var temperature: Float
    var topP: Float
    var contextLength: Int32
    var modelId: String?

    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message] = []

    init(
        title: String = "New Conversation",
        systemPrompt: String = "You are a helpful assistant.",
        temperature: Float = 0.7,
        topP: Float = 0.9,
        contextLength: Int32 = 2048,
        modelId: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.createdAt = .now
        self.updatedAt = .now
        self.systemPrompt = systemPrompt
        self.temperature = temperature
        self.topP = topP
        self.contextLength = contextLength
        self.modelId = modelId
    }
}
