import Foundation
import SwiftData
import Testing
@testable import HearthAI

// MARK: - Helpers

@MainActor
private func makeContext() throws -> ModelContext {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Conversation.self, Message.self, LocalModel.self,
        configurations: config
    )
    return container.mainContext
}

// MARK: - Stop-Generating Guard

@Test @MainActor func stopGeneratingWhenNotGeneratingIsNoOp() async {
    let viewModel = ChatViewModel()
    viewModel.streamingText = "partial text"
    viewModel.isGenerating = false

    await viewModel.stopGenerating()

    #expect(viewModel.messages.isEmpty, "No message should be appended when not generating")
    #expect(viewModel.streamingText == "partial text", "Text should remain unchanged")
}

@Test @MainActor func stopGeneratingSavesPartialText() async {
    let viewModel = ChatViewModel()
    viewModel.isGenerating = true
    viewModel.streamingText = "Hello world"

    await viewModel.stopGenerating()

    #expect(viewModel.messages.count == 1)
    #expect(viewModel.messages.first?.role == .assistant)
    #expect(viewModel.messages.first?.content == "Hello world")
    #expect(viewModel.isGenerating == false)
    #expect(viewModel.streamingText.isEmpty)
}

@Test @MainActor func stopGeneratingWithEmptyTextAppendsNothing() async {
    let viewModel = ChatViewModel()
    viewModel.isGenerating = true
    viewModel.streamingText = ""

    await viewModel.stopGenerating()

    #expect(viewModel.messages.isEmpty)
    #expect(viewModel.isGenerating == false)
}

// MARK: - Load Conversation

@Test @MainActor func loadConversationPopulatesMessages() throws {
    let context = try makeContext()
    let conversation = Conversation(title: "Test")
    context.insert(conversation)

    let msg1 = Message(role: .user, content: "Hello")
    msg1.conversation = conversation
    conversation.messages.append(msg1)

    let msg2 = Message(role: .assistant, content: "Hi there")
    msg2.conversation = conversation
    conversation.messages.append(msg2)
    try context.save()

    let viewModel = ChatViewModel()
    viewModel.modelContext = context
    viewModel.loadConversation(conversation)

    #expect(viewModel.messages.count == 2)
    #expect(viewModel.activeConversation?.id == conversation.id)
    #expect(viewModel.messages.first?.role == .user)
    #expect(viewModel.messages.last?.role == .assistant)
}

// MARK: - Delete Conversation

@Test @MainActor func deleteConversationRemovesFromContext() throws {
    let context = try makeContext()
    let conversation = Conversation(title: "To Delete")
    context.insert(conversation)
    try context.save()

    let viewModel = ChatViewModel()
    viewModel.modelContext = context

    viewModel.loadConversation(conversation)
    viewModel.deleteConversation(conversation)

    #expect(viewModel.activeConversation == nil)
    #expect(viewModel.messages.isEmpty)

    let descriptor = FetchDescriptor<Conversation>()
    let remaining = try context.fetch(descriptor)
    #expect(remaining.isEmpty)
}

// MARK: - Clear Messages

@Test @MainActor func clearMessagesDeletesConversationFromSwiftData() throws {
    let context = try makeContext()
    let conversation = Conversation(title: "Clear Me")
    context.insert(conversation)

    let msg = Message(role: .user, content: "test")
    msg.conversation = conversation
    conversation.messages.append(msg)
    try context.save()

    let viewModel = ChatViewModel()
    viewModel.modelContext = context
    viewModel.loadConversation(conversation)

    viewModel.clearMessages()

    #expect(viewModel.messages.isEmpty)
    #expect(viewModel.activeConversation == nil)

    let conversations = try context.fetch(FetchDescriptor<Conversation>())
    #expect(conversations.isEmpty)
}

// MARK: - Update Conversation Settings

@Test @MainActor func updateSettingsCreatesConversation() throws {
    let context = try makeContext()
    let viewModel = ChatViewModel()
    viewModel.modelContext = context

    #expect(viewModel.activeConversation == nil)

    viewModel.updateConversationSettings(
        systemPrompt: "You are a pirate.",
        temperature: 0.5,
        topP: 0.8
    )

    #expect(viewModel.activeConversation != nil)
    #expect(viewModel.activeConversation?.systemPrompt == "You are a pirate.")
    #expect(viewModel.activeConversation?.temperature == 0.5)
    #expect(viewModel.activeConversation?.topP == 0.8)
}

// MARK: - Conversation Config

@Test @MainActor func conversationConfigUsesConversationValues() throws {
    let context = try makeContext()
    let conversation = Conversation(
        temperature: 0.3,
        topP: 0.5
    )
    context.insert(conversation)
    try context.save()

    let viewModel = ChatViewModel()
    viewModel.modelContext = context
    viewModel.loadConversation(conversation)

    let config = viewModel.conversationConfig
    #expect(config.temperature == 0.3)
    #expect(config.topP == 0.5)
}

@Test @MainActor func conversationConfigFallsBackToDefault() {
    let viewModel = ChatViewModel()
    let config = viewModel.conversationConfig
    #expect(config.temperature == 0.7)
    #expect(config.topP == 0.9)
}
