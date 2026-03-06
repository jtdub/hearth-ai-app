import Foundation
import SwiftData

@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var streamingText = ""
    var isGenerating = false
    var inferenceService: InferenceService?
    var thermalMonitor: ThermalMonitor?

    // Conversation persistence
    var activeConversation: Conversation?
    var modelContext: ModelContext?

    private var config = InferenceConfiguration.default

    var conversationConfig: InferenceConfiguration {
        guard let conv = activeConversation else { return config }
        return InferenceConfiguration(
            maxTokens: config.maxTokens,
            temperature: conv.temperature,
            topP: conv.topP,
            repeatPenalty: config.repeatPenalty
        )
    }

    func send(_ text: String) async {
        guard let inferenceService, inferenceService.isModelLoaded else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        persistMessage(role: .user, content: text)

        let prompt = buildPrompt()

        isGenerating = true
        streamingText = ""

        let currentConfig = conversationConfig
        guard let stream = inferenceService.generate(prompt: prompt, config: currentConfig) else {
            isGenerating = false
            return
        }

        for await token in stream {
            if thermalMonitor?.isCritical == true {
                await inferenceService.cancelGeneration()
                break
            }
            streamingText += token
        }

        if !streamingText.isEmpty {
            let assistantMessage = ChatMessage(role: .assistant, content: streamingText)
            messages.append(assistantMessage)
            persistMessage(role: .assistant, content: streamingText)
            autoTitleConversation()
        }
        streamingText = ""
        isGenerating = false
    }

    func stopGenerating() async {
        await inferenceService?.cancelGeneration()
        if !streamingText.isEmpty {
            let partial = ChatMessage(role: .assistant, content: streamingText)
            messages.append(partial)
            persistMessage(role: .assistant, content: streamingText)
        }
        streamingText = ""
        isGenerating = false
    }

    func clearMessages() {
        messages.removeAll()
        streamingText = ""
    }

    func regenerateLastResponse() async {
        guard let last = messages.last, last.role == .assistant else { return }
        messages.removeLast()
        deleteLastPersistedMessage()
        if let lastUser = messages.last, lastUser.role == .user {
            let text = lastUser.content
            messages.removeLast()
            deleteLastPersistedMessage()
            await send(text)
        }
    }

    // MARK: - Conversation Management

    func newConversation() {
        activeConversation = nil
        messages.removeAll()
        streamingText = ""
    }

    func loadConversation(_ conversation: Conversation) {
        activeConversation = conversation
        messages = conversation.messages
            .sorted { $0.createdAt < $1.createdAt }
            .map { ChatMessage(role: $0.role, content: $0.content) }
        streamingText = ""
    }

    func deleteConversation(_ conversation: Conversation) {
        if activeConversation?.id == conversation.id {
            newConversation()
        }
        modelContext?.delete(conversation)
        try? modelContext?.save()
    }

    func updateConversationSettings(
        systemPrompt: String,
        temperature: Float,
        topP: Float
    ) {
        ensureActiveConversation()
        activeConversation?.systemPrompt = systemPrompt
        activeConversation?.temperature = temperature
        activeConversation?.topP = topP
        activeConversation?.updatedAt = .now
        try? modelContext?.save()
    }

    // MARK: - Persistence

    private func ensureActiveConversation() {
        guard activeConversation == nil, let modelContext else { return }
        let conversation = Conversation(modelId: inferenceService?.loadedModelId)
        modelContext.insert(conversation)
        activeConversation = conversation
        try? modelContext.save()
    }

    private func persistMessage(role: MessageRole, content: String) {
        guard let modelContext else { return }
        ensureActiveConversation()
        let message = Message(role: role, content: content)
        message.conversation = activeConversation
        activeConversation?.messages.append(message)
        activeConversation?.updatedAt = .now
        try? modelContext.save()
    }

    private func deleteLastPersistedMessage() {
        guard let conversation = activeConversation,
              let lastMessage = conversation.messages
                .sorted(by: { $0.createdAt < $1.createdAt }).last else { return }
        modelContext?.delete(lastMessage)
        try? modelContext?.save()
    }

    private func autoTitleConversation() {
        guard let conversation = activeConversation,
              conversation.title == "New Conversation",
              let firstUser = messages.first(where: { $0.role == .user }) else { return }
        let title = String(firstUser.content.prefix(50))
        conversation.title = title.count < firstUser.content.count ? title + "..." : title
        try? modelContext?.save()
    }

    // MARK: - Prompt Building

    private func buildPrompt() -> String {
        let systemPrompt = activeConversation?.systemPrompt ?? "You are a helpful assistant."
        var prompt = "<|im_start|>system\n\(systemPrompt)<|im_end|>\n"

        for message in messages {
            let role = message.role == .user ? "user" : "assistant"
            prompt += "<|im_start|>\(role)\n\(message.content)<|im_end|>\n"
        }

        prompt += "<|im_start|>assistant\n"
        return prompt
    }
}

/// Lightweight chat message for the view layer.
struct ChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let createdAt = Date()
}
