import Testing
import Foundation
import SwiftData
@testable import HearthAI

@Suite(.serialized)
@MainActor
struct MemoryModelTests {

    @Test func memoryInitDefaults() throws {
        let memory = Memory(content: "User likes Swift")
        #expect(memory.content == "User likes Swift")
        #expect(memory.category == MemoryCategory.other.rawValue)
        #expect(memory.isActive == true)
        #expect(memory.tokenEstimate == Int32("User likes Swift".count / 4))
    }

    @Test func memoryInitWithCategory() throws {
        let memory = Memory(
            content: "Always use dark mode",
            category: .preference
        )
        #expect(memory.memoryCategory == .preference)
        #expect(memory.isActive == true)
    }

    @Test func memoryInitInactive() throws {
        let memory = Memory(
            content: "Old fact",
            category: .fact,
            isActive: false
        )
        #expect(memory.isActive == false)
        #expect(memory.memoryCategory == .fact)
    }

    @Test func memoryCategoryDisplayNames() throws {
        #expect(MemoryCategory.preference.displayName == "Preference")
        #expect(MemoryCategory.fact.displayName == "Fact")
        #expect(MemoryCategory.instruction.displayName == "Instruction")
        #expect(MemoryCategory.other.displayName == "Other")
    }

    @Test func memoryCategorySystemImages() throws {
        #expect(!MemoryCategory.preference.systemImage.isEmpty)
        #expect(!MemoryCategory.fact.systemImage.isEmpty)
        #expect(!MemoryCategory.instruction.systemImage.isEmpty)
        #expect(!MemoryCategory.other.systemImage.isEmpty)
    }

    @Test func memoryTokenEstimate() throws {
        let content = String(repeating: "word ", count: 100)
        let memory = Memory(content: content)
        #expect(memory.tokenEstimate == Int32(content.count / 4))
    }

    @Test func memoryPersistence() throws {
        let context = try TestModelContainer.makeContext()
        try TestModelContainer.cleanUp(context)

        let memory = Memory(
            content: "Prefers concise answers",
            category: .preference
        )
        context.insert(memory)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Memory>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.content == "Prefers concise answers")
        #expect(fetched.first?.memoryCategory == .preference)

        try TestModelContainer.cleanUp(context)
    }

    @Test func memoryUpdateTimestamp() throws {
        let memory = Memory(content: "Original")
        let originalDate = memory.updatedAt

        // Small delay to ensure different timestamp
        memory.content = "Updated"
        memory.updatedAt = .now

        #expect(memory.updatedAt >= originalDate)
        #expect(memory.content == "Updated")
    }

    @Test func conversationUseMemoryDefault() throws {
        let conversation = Conversation()
        #expect(conversation.useMemory == true)
    }

    @Test func conversationUseMemoryDisabled() throws {
        let conversation = Conversation(useMemory: false)
        #expect(conversation.useMemory == false)
    }

    @Test func memoryCategoryFromRawValue() throws {
        let memory = Memory(content: "test")
        memory.category = "preference"
        #expect(memory.memoryCategory == .preference)

        memory.category = "invalid"
        #expect(memory.memoryCategory == .other)
    }
}
