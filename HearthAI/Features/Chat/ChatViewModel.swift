import Foundation
import SwiftData

@MainActor
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

    // Document Q&A
    var attachedDocument: Document?

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

        let stopTokens = ["<|im_end|>", "<|im_start|>", "<|endoftext|>"]

        for await token in stream {
            if thermalMonitor?.isCritical == true {
                await inferenceService.cancelGeneration()
                break
            }
            streamingText += token

            // Stop if a chat template stop token appears in the output
            if stopTokens.contains(where: { streamingText.hasSuffix($0) }) {
                for stop in stopTokens where streamingText.hasSuffix(stop) {
                    streamingText = String(streamingText.dropLast(stop.count))
                }
                await inferenceService.cancelGeneration()
                break
            }
        }

        // Clean any remaining stop tokens that may have been split across yields
        for stop in stopTokens {
            streamingText = streamingText.replacingOccurrences(of: stop, with: "")
        }
        streamingText = streamingText.trimmingCharacters(in: .whitespacesAndNewlines)

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
        guard isGenerating else { return }
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
        if let conversation = activeConversation {
            modelContext?.delete(conversation)
            try? modelContext?.save()
        }
        activeConversation = nil
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

    // MARK: - Document Attachment

    func attachDocument(_ document: Document) {
        attachedDocument = document
        ensureActiveConversation()
        activeConversation?.documentId = document.id
        try? modelContext?.save()
    }

    func detachDocument() {
        attachedDocument = nil
        activeConversation?.documentId = nil
        try? modelContext?.save()
    }

    // MARK: - Conversation Management

    func newConversation() {
        activeConversation = nil
        attachedDocument = nil
        messages.removeAll()
        streamingText = ""
    }

    func loadConversation(_ conversation: Conversation) {
        activeConversation = conversation
        messages = conversation.messages
            .sorted { $0.createdAt < $1.createdAt }
            .map { ChatMessage(role: $0.role, content: $0.content) }
        streamingText = ""
        loadAttachedDocument(for: conversation)
    }

    private func loadAttachedDocument(for conversation: Conversation) {
        guard let docId = conversation.documentId,
              let context = modelContext else {
            attachedDocument = nil
            return
        }
        var descriptor = FetchDescriptor<Document>(
            predicate: #Predicate { $0.id == docId }
        )
        descriptor.fetchLimit = 1
        attachedDocument = try? context.fetch(descriptor).first
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
        let basePrompt = activeConversation?.systemPrompt
            ?? "You are a helpful assistant."
        let documentContext = buildDocumentContext()
        let systemPrompt = documentContext.isEmpty
            ? basePrompt
            : basePrompt + "\n\n" + documentContext

        var prompt = "<|im_start|>system\n\(systemPrompt)<|im_end|>\n"

        for message in messages {
            let role = message.role == .user ? "user" : "assistant"
            prompt += "<|im_start|>\(role)\n\(message.content)"
            prompt += "<|im_end|>\n"
        }

        prompt += "<|im_start|>assistant\n"
        return prompt
    }

    private func buildDocumentContext() -> String {
        guard let document = attachedDocument,
              !document.chunks.isEmpty else {
            return ""
        }

        let lastUserMessage = messages.last {
            $0.role == .user
        }?.content ?? ""

        let contextLength = Int(
            activeConversation?.contextLength
                ?? Constants.defaultContextSize
        )
        let tokenBudget = Int(
            Float(contextLength)
                * Constants.documentTokenBudgetFraction
        )

        let selectedChunks = ChunkSelectorService.selectChunks(
            query: lastUserMessage,
            chunks: document.chunks,
            maxTokenBudget: tokenBudget
        )

        guard !selectedChunks.isEmpty else { return "" }

        let excerpts = selectedChunks
            .sorted { $0.chunkIndex < $1.chunkIndex }
            .map(\.content)
            .joined(separator: "\n\n---\n\n")

        return """
        Answer based on the following document excerpts \
        from "\(document.title)":

        ---
        \(excerpts)
        ---
        """
    }
}

/// Lightweight chat message for the view layer.
struct ChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let createdAt = Date()
}
