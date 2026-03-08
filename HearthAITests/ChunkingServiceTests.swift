import Foundation
import Testing
@testable import HearthAI

@Suite
struct ChunkingServiceTests {

    @Test func emptyTextReturnsNoChunks() {
        let chunks = ChunkingService.chunk(text: "")
        #expect(chunks.isEmpty)
    }

    @Test func whitespaceOnlyReturnsNoChunks() {
        let chunks = ChunkingService.chunk(text: "   \n\n  ")
        #expect(chunks.isEmpty)
    }

    @Test func shortTextReturnsSingleChunk() {
        let text = "Hello, this is a short document."
        let chunks = ChunkingService.chunk(text: text)
        #expect(chunks.count == 1)
        #expect(chunks.first == text)
    }

    @Test func multiParagraphChunking() {
        // Create text with multiple paragraphs that together exceed
        // one chunk
        let paragraph = String(repeating: "word ", count: 200)
        let text = paragraph + "\n\n" + paragraph + "\n\n" + paragraph

        let chunks = ChunkingService.chunk(
            text: text, maxTokens: 300, overlapTokens: 20
        )

        #expect(chunks.count >= 2)
        // Verify all chunks are non-empty
        for chunk in chunks {
            #expect(!chunk.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty)
        }
    }

    @Test func chunksHaveOverlap() {
        let para1 = String(repeating: "alpha ", count: 150)
        let para2 = String(repeating: "beta ", count: 150)
        let text = para1 + "\n\n" + para2

        let chunks = ChunkingService.chunk(
            text: text, maxTokens: 200, overlapTokens: 30
        )

        #expect(chunks.count >= 2)
        // The end of the first chunk should appear at the start
        // of the second
        if chunks.count >= 2 {
            let firstEnd = String(chunks[0].suffix(100))
            let words = firstEnd.split(separator: " ")
            if let lastWord = words.last {
                #expect(chunks[1].contains(String(lastWord)))
            }
        }
    }

    @Test func singleLongParagraphGetsSplit() {
        // One huge paragraph with no double newlines
        let text = String(repeating: "test sentence. ", count: 500)

        let chunks = ChunkingService.chunk(
            text: text, maxTokens: 200, overlapTokens: 20
        )

        #expect(chunks.count >= 2)
    }

    @Test func customMaxTokensRespected() {
        let text = String(repeating: "hello ", count: 300)
        let maxTokens = 100
        let maxChars = maxTokens * 4

        let chunks = ChunkingService.chunk(
            text: text, maxTokens: maxTokens, overlapTokens: 10
        )

        // Each chunk should be roughly within the max size
        // (with some tolerance for sentence boundaries)
        for chunk in chunks {
            #expect(chunk.count <= maxChars * 2)
        }
    }

    @Test func preservesParagraphBoundaries() {
        let text = "First paragraph.\n\nSecond paragraph.\n\nThird."
        let chunks = ChunkingService.chunk(
            text: text, maxTokens: 500, overlapTokens: 10
        )

        #expect(chunks.count == 1)
        #expect(chunks.first?.contains("First paragraph.") == true)
        #expect(chunks.first?.contains("Second paragraph.") == true)
        #expect(chunks.first?.contains("Third.") == true)
    }
}
