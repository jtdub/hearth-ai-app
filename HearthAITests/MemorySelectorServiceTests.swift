import Testing
import Foundation
import SwiftData
@testable import HearthAI

@Suite(.serialized)
@MainActor
struct MemorySelectorServiceTests {

    private func makeMemory(
        _ content: String,
        category: MemoryCategory = .other,
        isActive: Bool = true
    ) -> Memory {
        Memory(content: content, category: category, isActive: isActive)
    }

    @Test func emptyMemoriesReturnsEmpty() {
        let result = MemorySelectorService.selectMemories(
            query: "hello",
            memories: [],
            maxTokenBudget: 100
        )
        #expect(result.isEmpty)
    }

    @Test func emptyQueryReturnsEmpty() {
        let mem1 = makeMemory("some memory")
        let mem2 = makeMemory("another memory")

        let result = MemorySelectorService.selectMemories(
            query: "",
            memories: [mem1, mem2],
            maxTokenBudget: 1000
        )
        #expect(result.isEmpty)
    }

    @Test func filtersInactiveMemories() {
        let active = makeMemory("active memory about Swift")
        let inactive = makeMemory(
            "inactive memory about Swift",
            isActive: false
        )

        let result = MemorySelectorService.selectMemories(
            query: "Swift",
            memories: [active, inactive],
            maxTokenBudget: 1000
        )
        #expect(result.count == 1)
        #expect(result.first?.content == "active memory about Swift")
    }

    @Test func ranksRelevantMemoriesHigher() {
        let relevant = makeMemory(
            "User prefers dark mode and dark themes"
        )
        let irrelevant = makeMemory(
            "User has a cat named Whiskers"
        )

        let result = MemorySelectorService.selectMemories(
            query: "dark mode preference",
            memories: [irrelevant, relevant],
            maxTokenBudget: 1000
        )
        #expect(result.first?.content.contains("dark") == true)
    }

    @Test func respectsTokenBudget() {
        let longContent = String(repeating: "word ", count: 200)
        let big = makeMemory(longContent)
        let small = makeMemory("short memory about coding")

        let result = MemorySelectorService.selectMemories(
            query: "coding",
            memories: [big, small],
            maxTokenBudget: 20
        )
        // Should include at least the most relevant one
        #expect(!result.isEmpty)
    }

    @Test func alwaysIncludesAtLeastOneMemory() {
        let memory = makeMemory(
            "This is a very long memory content"
        )

        let result = MemorySelectorService.selectMemories(
            query: "memory content",
            memories: [memory],
            maxTokenBudget: 1
        )
        #expect(result.count == 1)
    }

    @Test func multipleRelevantMemories() {
        let swift1 = makeMemory("User codes in Swift language")
        let swift2 = makeMemory("User builds iOS apps with Swift")
        let hiking = makeMemory("User enjoys hiking outdoors")

        let result = MemorySelectorService.selectMemories(
            query: "Swift programming",
            memories: [swift1, swift2, hiking],
            maxTokenBudget: 1000
        )
        #expect(result.count >= 2)
    }

    @Test func shortQueryTermsFiltered() {
        let memory = makeMemory("User prefers concise answers")

        // Query with only short words (<=2 chars) should fall back
        // to recency
        let result = MemorySelectorService.selectMemories(
            query: "is it ok",
            memories: [memory],
            maxTokenBudget: 1000
        )
        // Should still return memories (by recency fallback)
        #expect(!result.isEmpty)
    }

    @Test func persistedMemorySelection() throws {
        let context = try TestModelContainer.makeContext()
        try TestModelContainer.cleanUp(context)

        let swiftMem = Memory(
            content: "User prefers Swift programming",
            category: .preference
        )
        let locationMem = Memory(
            content: "User lives in Austin Texas",
            category: .fact
        )
        context.insert(swiftMem)
        context.insert(locationMem)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Memory>())
        let result = MemorySelectorService.selectMemories(
            query: "Swift coding",
            memories: fetched,
            maxTokenBudget: 500
        )
        #expect(!result.isEmpty)
        #expect(
            result.first?.content.contains("Swift") == true
        )

        try TestModelContainer.cleanUp(context)
    }
}
