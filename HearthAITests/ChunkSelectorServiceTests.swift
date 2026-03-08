import Foundation
import Testing
@testable import HearthAI

@Suite
struct ChunkSelectorServiceTests {

    private func makeChunk(
        content: String, index: Int32
    ) -> DocumentChunk {
        DocumentChunk(content: content, chunkIndex: index)
    }

    @Test func emptyChunksReturnsEmpty() {
        let result = ChunkSelectorService.selectChunks(
            query: "test", chunks: [], maxTokenBudget: 1000
        )
        #expect(result.isEmpty)
    }

    @Test func emptyQueryReturnsEmpty() {
        let chunk = makeChunk(content: "Some content", index: 0)
        let result = ChunkSelectorService.selectChunks(
            query: "", chunks: [chunk], maxTokenBudget: 1000
        )
        #expect(result.isEmpty)
    }

    @Test func selectsMostRelevantChunk() {
        let chunk1 = makeChunk(
            content: "The weather is sunny and warm today",
            index: 0
        )
        let chunk2 = makeChunk(
            content: "Swift programming language is great for iOS apps",
            index: 1
        )
        let chunk3 = makeChunk(
            content: "The temperature and weather forecast looks good",
            index: 2
        )

        let result = ChunkSelectorService.selectChunks(
            query: "What is the weather?",
            chunks: [chunk1, chunk2, chunk3],
            maxTokenBudget: 100
        )

        #expect(!result.isEmpty)
        // Weather-related chunks should rank higher
        let selectedContents = result.map(\.content)
        let hasWeatherChunk = selectedContents.contains {
            $0.contains("weather")
        }
        #expect(hasWeatherChunk)
    }

    @Test func respectsTokenBudget() {
        // Each chunk has ~25 token estimate (100 chars / 4)
        let chunks = (0..<10).map { index in
            makeChunk(
                content: String(
                    repeating: "test word content here. ",
                    count: 4
                ),
                index: Int32(index)
            )
        }

        let result = ChunkSelectorService.selectChunks(
            query: "test content",
            chunks: chunks,
            maxTokenBudget: 50
        )

        let totalTokens = result.reduce(0) {
            $0 + Int($1.tokenEstimate)
        }
        // Should not exceed budget (except for the "always include
        // at least one" rule)
        #expect(
            totalTokens <= 50
            || (result.count == 1 && totalTokens > 0)
        )
    }

    @Test func alwaysIncludesAtLeastOneChunk() {
        let chunk = makeChunk(
            content: String(repeating: "large ", count: 200),
            index: 0
        )

        let result = ChunkSelectorService.selectChunks(
            query: "large",
            chunks: [chunk],
            maxTokenBudget: 10
        )

        #expect(result.count == 1)
    }

    @Test func ranksMultipleMatchesHigher() {
        let chunk1 = makeChunk(
            content: "apple apple apple banana",
            index: 0
        )
        let chunk2 = makeChunk(
            content: "cherry grape lemon orange",
            index: 1
        )

        let result = ChunkSelectorService.selectChunks(
            query: "apple banana",
            chunks: [chunk1, chunk2],
            maxTokenBudget: 1000
        )

        // chunk1 should be first since it has the query terms
        #expect(result.first?.content.contains("apple") == true)
    }
}
