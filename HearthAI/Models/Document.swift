import Foundation
import SwiftData

@Model
final class Document {
    @Attribute(.unique) var id: UUID
    var title: String
    var sourceType: String
    var importedAt: Date
    var rawText: String
    var fileSize: Int64
    var pageCount: Int32?

    @Relationship(deleteRule: .cascade, inverse: \DocumentChunk.document)
    var chunks: [DocumentChunk] = []

    init(
        title: String,
        sourceType: DocumentSourceType = .txt,
        rawText: String = "",
        fileSize: Int64 = 0,
        pageCount: Int32? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.sourceType = sourceType.rawValue
        self.importedAt = .now
        self.rawText = rawText
        self.fileSize = fileSize
        self.pageCount = pageCount
    }

    var documentSourceType: DocumentSourceType {
        DocumentSourceType(rawValue: sourceType) ?? .txt
    }

    var chunkCount: Int {
        chunks.count
    }

    var wordCount: Int {
        rawText.split(separator: " ").count
    }
}

enum DocumentSourceType: String, Codable, CaseIterable {
    case pdf
    case txt
    case image

    var displayName: String {
        switch self {
        case .pdf: "PDF"
        case .txt: "Text"
        case .image: "Image (OCR)"
        }
    }

    var systemImage: String {
        switch self {
        case .pdf: "doc.richtext"
        case .txt: "doc.plaintext"
        case .image: "photo"
        }
    }
}
