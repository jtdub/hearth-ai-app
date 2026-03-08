import Foundation
import SwiftData
import Testing
@testable import HearthAI

@Suite(.serialized)
@MainActor
struct DocumentModelTests {

    // MARK: - Document Creation

    @Test func documentDefaultValues() {
        let doc = Document(title: "Test Doc")
        #expect(doc.title == "Test Doc")
        #expect(doc.documentSourceType == .txt)
        #expect(doc.rawText.isEmpty)
        #expect(doc.fileSize == 0)
        #expect(doc.pageCount == nil)
        #expect(doc.chunks.isEmpty)
    }

    @Test func documentCustomValues() {
        let doc = Document(
            title: "My PDF",
            sourceType: .pdf,
            rawText: "Hello world",
            fileSize: 1024,
            pageCount: 5
        )
        #expect(doc.title == "My PDF")
        #expect(doc.documentSourceType == .pdf)
        #expect(doc.rawText == "Hello world")
        #expect(doc.fileSize == 1024)
        #expect(doc.pageCount == 5)
    }

    @Test func documentWordCount() {
        let doc = Document(
            title: "Test",
            rawText: "one two three four five"
        )
        #expect(doc.wordCount == 5)
    }

    // MARK: - DocumentChunk Creation

    @Test func chunkTokenEstimate() {
        let chunk = DocumentChunk(
            content: String(repeating: "a", count: 100),
            chunkIndex: 0
        )
        #expect(chunk.tokenEstimate == 25) // 100 / 4
    }

    @Test func chunkCustomTokenEstimate() {
        let chunk = DocumentChunk(
            content: "hello", chunkIndex: 0, tokenEstimate: 42
        )
        #expect(chunk.tokenEstimate == 42)
    }

    // MARK: - DocumentSourceType

    @Test func sourceTypeDisplayNames() {
        #expect(DocumentSourceType.pdf.displayName == "PDF")
        #expect(DocumentSourceType.txt.displayName == "Text")
        #expect(DocumentSourceType.image.displayName == "Image (OCR)")
    }

    @Test func sourceTypeSystemImages() {
        #expect(!DocumentSourceType.pdf.systemImage.isEmpty)
        #expect(!DocumentSourceType.txt.systemImage.isEmpty)
        #expect(!DocumentSourceType.image.systemImage.isEmpty)
    }

    // MARK: - SwiftData Persistence

    @Test func documentPersistsWithChunks() throws {
        let context = try TestModelContainer.makeContext()
        try TestModelContainer.cleanUp(context)

        let doc = Document(
            title: "Persisted Doc",
            rawText: "Some text"
        )
        context.insert(doc)

        let chunk1 = DocumentChunk(content: "chunk one", chunkIndex: 0)
        chunk1.document = doc
        doc.chunks.append(chunk1)

        let chunk2 = DocumentChunk(content: "chunk two", chunkIndex: 1)
        chunk2.document = doc
        doc.chunks.append(chunk2)

        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Document>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.chunks.count == 2)
        #expect(fetched.first?.chunkCount == 2)
    }

    @Test func deletingDocumentCascadesToChunks() throws {
        let context = try TestModelContainer.makeContext()
        try TestModelContainer.cleanUp(context)

        let doc = Document(title: "To Delete")
        context.insert(doc)

        let chunk = DocumentChunk(content: "data", chunkIndex: 0)
        chunk.document = doc
        doc.chunks.append(chunk)
        try context.save()

        let chunksBefore = try context.fetch(
            FetchDescriptor<DocumentChunk>()
        )
        #expect(chunksBefore.count == 1)

        context.delete(doc)
        try context.save()

        let docs = try context.fetch(FetchDescriptor<Document>())
        #expect(docs.isEmpty)

        let chunksAfter = try context.fetch(
            FetchDescriptor<DocumentChunk>()
        )
        for chunk in chunksAfter {
            #expect(chunk.document == nil)
        }
    }

    // MARK: - Conversation Document Reference

    @Test func conversationDocumentId() throws {
        let context = try TestModelContainer.makeContext()
        try TestModelContainer.cleanUp(context)

        let docId = UUID()
        let conversation = Conversation(
            title: "Doc Chat", documentId: docId
        )
        context.insert(conversation)
        try context.save()

        let fetched = try context.fetch(
            FetchDescriptor<Conversation>()
        )
        #expect(fetched.first?.documentId == docId)
    }

    @Test func conversationDocumentIdDefaultsNil() {
        let conversation = Conversation(title: "Normal Chat")
        #expect(conversation.documentId == nil)
    }

    // MARK: - DocumentError

    @Test func documentErrorDescriptions() {
        let err1 = DocumentError.unableToReadFile("test.pdf")
        #expect(err1.errorDescription?.contains("test.pdf") == true)

        let err2 = DocumentError.noTextContent("empty.pdf")
        #expect(err2.errorDescription?.contains("empty.pdf") == true)

        let err3 = DocumentError.ocrUnavailable
        #expect(err3.errorDescription?.contains("OCR") == true)

        let err4 = DocumentError.unsupportedFormat("xyz")
        #expect(err4.errorDescription?.contains("xyz") == true)
    }
}
