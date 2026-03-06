import Foundation

@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var streamingText = ""
    var isGenerating = false
    var inferenceService: InferenceService?

    private var config = InferenceConfiguration.default

    func send(_ text: String) async {
        guard let inferenceService, inferenceService.isModelLoaded else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)

        let prompt = buildPrompt()

        isGenerating = true
        streamingText = ""

        guard let stream = inferenceService.generate(prompt: prompt, config: config) else {
            isGenerating = false
            return
        }

        for await token in stream {
            streamingText += token
        }

        let assistantMessage = ChatMessage(role: .assistant, content: streamingText)
        messages.append(assistantMessage)
        streamingText = ""
        isGenerating = false
    }

    func stopGenerating() async {
        await inferenceService?.cancelGeneration()
        if !streamingText.isEmpty {
            let partial = ChatMessage(role: .assistant, content: streamingText)
            messages.append(partial)
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
        if let lastUser = messages.last, lastUser.role == .user {
            let text = lastUser.content
            messages.removeLast()
            await send(text)
        }
    }

    // MARK: - Prompt Building

    private func buildPrompt() -> String {
        // Simple ChatML-style template as default
        var prompt = "<|im_start|>system\nYou are a helpful assistant.<|im_end|>\n"

        for message in messages {
            let role = message.role == .user ? "user" : "assistant"
            prompt += "<|im_start|>\(role)\n\(message.content)<|im_end|>\n"
        }

        prompt += "<|im_start|>assistant\n"
        return prompt
    }
}

/// Lightweight chat message for the view layer (not persisted to SwiftData yet).
struct ChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let createdAt = Date()
}
