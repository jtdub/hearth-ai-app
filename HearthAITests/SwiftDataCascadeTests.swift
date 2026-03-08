import Foundation
import SwiftData
import Testing
@testable import HearthAI

@Suite(.serialized)
@MainActor
struct SwiftDataCascadeTests {

    // MARK: - Cascade Delete

    @Test
    func deletingConversationCascadesToMessages() throws {
        let context = try TestModelContainer.makeContext()
        try TestModelContainer.cleanUp(context)

        let conversation = Conversation(title: "Cascade Test")
        context.insert(conversation)

        let msg1 = Message(role: .user, content: "Hello")
        msg1.conversation = conversation
        conversation.messages.append(msg1)

        let msg2 = Message(role: .assistant, content: "Hi")
        msg2.conversation = conversation
        conversation.messages.append(msg2)

        try context.save()

        // Verify setup
        let messagesBefore = try context.fetch(FetchDescriptor<Message>())
        #expect(messagesBefore.count == 2)

        // Delete conversation — cascade should remove messages
        context.delete(conversation)
        try context.save()

        let conversations = try context.fetch(FetchDescriptor<Conversation>())
        #expect(conversations.isEmpty)

        // After cascade, messages should have nil conversation
        let messagesAfter = try context.fetch(FetchDescriptor<Message>())
        for msg in messagesAfter {
            #expect(msg.conversation == nil)
        }
    }

    // MARK: - Conversation Defaults

    @Test func conversationDefaultValues() throws {
        let conversation = Conversation()
        #expect(conversation.title == "New Conversation")
        #expect(conversation.systemPrompt == "You are a helpful assistant.")
        #expect(conversation.temperature == 0.7)
        #expect(conversation.topP == 0.9)
        #expect(conversation.contextLength == 2048)
        #expect(conversation.modelId == nil)
        #expect(conversation.messages.isEmpty)
    }

    @Test func conversationCustomValues() throws {
        let conversation = Conversation(
            title: "Custom",
            systemPrompt: "Be brief.",
            temperature: 0.3,
            topP: 0.5,
            contextLength: 4096,
            modelId: "test/model"
        )
        #expect(conversation.title == "Custom")
        #expect(conversation.systemPrompt == "Be brief.")
        #expect(conversation.temperature == 0.3)
        #expect(conversation.topP == 0.5)
        #expect(conversation.contextLength == 4096)
        #expect(conversation.modelId == "test/model")
    }

    // MARK: - Message

    @Test func messageCreation() {
        let msg = Message(role: .user, content: "Hello")
        #expect(msg.role == .user)
        #expect(msg.content == "Hello")
        #expect(msg.conversation == nil)
        #expect(msg.tokenCount == nil)
    }

    @Test func messageWithTokenCount() {
        let msg = Message(role: .assistant, content: "Hi", tokenCount: 42)
        #expect(msg.tokenCount == 42)
    }

    // MARK: - Message Role

    @Test func messageRoleRawValues() {
        #expect(MessageRole.system.rawValue == "system")
        #expect(MessageRole.user.rawValue == "user")
        #expect(MessageRole.assistant.rawValue == "assistant")
    }

    // MARK: - LocalModel

    @Test func localModelAbsolutePath() throws {
        let model = LocalModel(
            id: "test/repo/model.gguf",
            repoId: "test/repo",
            fileName: "model.gguf",
            displayName: "Test Model",
            modelFamily: "Llama",
            quantization: "Q4_K_M",
            fileSizeBytes: 1_000_000,
            localPath: "test_repo/model.gguf"
        )
        let expected = FileManager.modelsDirectory
            .appendingPathComponent("test_repo/model.gguf")
        #expect(model.absolutePath == expected)
    }

    // MARK: - Multiple Conversations

    @Test
    func multipleConversationsIndependent() throws {
        let context = try TestModelContainer.makeContext()
        try TestModelContainer.cleanUp(context)

        let conv1 = Conversation(title: "First")
        let conv2 = Conversation(title: "Second")
        context.insert(conv1)
        context.insert(conv2)

        let msg1 = Message(role: .user, content: "In first")
        msg1.conversation = conv1
        conv1.messages.append(msg1)

        let msg2 = Message(role: .user, content: "In second")
        msg2.conversation = conv2
        conv2.messages.append(msg2)
        try context.save()

        // Delete first conversation
        context.delete(conv1)
        try context.save()

        // Second conversation should survive with its message
        let conversations = try context.fetch(FetchDescriptor<Conversation>())
        #expect(conversations.count == 1)
        #expect(conversations.first?.title == "Second")
        #expect(conversations.first?.messages.count == 1)
        #expect(conversations.first?.messages.first?.content == "In second")
    }
}
