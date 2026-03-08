import Foundation
import SwiftData
@testable import HearthAI

@MainActor
enum TestModelContainer {
    private static var _container: ModelContainer?

    static var shared: ModelContainer {
        get throws {
            if let existing = _container {
                return existing
            }
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(
                for: Conversation.self, Message.self, LocalModel.self,
                Document.self, DocumentChunk.self,
                configurations: config
            )
            _container = container
            return container
        }
    }

    static func makeContext() throws -> ModelContext {
        try shared.mainContext
    }

    static func cleanUp(_ context: ModelContext) throws {
        try context.fetch(FetchDescriptor<DocumentChunk>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<Document>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<Message>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<Conversation>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<LocalModel>()).forEach { context.delete($0) }
        try context.save()
    }
}
