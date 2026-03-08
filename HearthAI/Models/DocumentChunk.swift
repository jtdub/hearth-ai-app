import Foundation
import SwiftData

@Model
final class DocumentChunk {
    @Attribute(.unique) var id: UUID
    var content: String
    var chunkIndex: Int32
    var tokenEstimate: Int32

    var document: Document?

    init(
        content: String,
        chunkIndex: Int32,
        tokenEstimate: Int32? = nil
    ) {
        self.id = UUID()
        self.content = content
        self.chunkIndex = chunkIndex
        self.tokenEstimate = tokenEstimate
            ?? Int32(content.count / 4)
    }
}
