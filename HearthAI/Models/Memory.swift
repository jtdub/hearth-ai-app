import Foundation
import SwiftData

@Model
final class Memory {
    @Attribute(.unique) var id: UUID
    var content: String
    var category: String
    var createdAt: Date
    var updatedAt: Date
    var isActive: Bool
    var tokenEstimate: Int32

    init(
        content: String,
        category: MemoryCategory = .other,
        isActive: Bool = true
    ) {
        self.id = UUID()
        self.content = content
        self.category = category.rawValue
        self.createdAt = .now
        self.updatedAt = .now
        self.isActive = isActive
        self.tokenEstimate = Int32(content.count / 4)
    }

    var memoryCategory: MemoryCategory {
        MemoryCategory(rawValue: category) ?? .other
    }
}

enum MemoryCategory: String, Codable, CaseIterable {
    case preference
    case fact
    case instruction
    case other

    var displayName: String {
        switch self {
        case .preference: "Preference"
        case .fact: "Fact"
        case .instruction: "Instruction"
        case .other: "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .preference: "heart"
        case .fact: "info.circle"
        case .instruction: "list.bullet.rectangle"
        case .other: "square.and.pencil"
        }
    }
}
