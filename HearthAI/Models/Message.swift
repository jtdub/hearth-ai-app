import Foundation
import SwiftData

@Model
final class Message {
    @Attribute(.unique) var id: UUID
    var role: MessageRole
    var content: String
    var createdAt: Date
    var tokenCount: Int32?

    var conversation: Conversation?

    init(role: MessageRole, content: String, tokenCount: Int32? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.createdAt = .now
        self.tokenCount = tokenCount
    }
}

enum MessageRole: String, Codable {
    case system
    case user
    case assistant
}
