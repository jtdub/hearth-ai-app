import Foundation

enum PreviewData {
    static let sampleMessages: [ChatMessage] = [
        ChatMessage(
            role: .user,
            content: "Hello! What can you help me with?"
        ),
        ChatMessage(
            role: .assistant,
            content: "Hi there! I'm Hearth AI, your private on-device assistant. "
                + "I can help with writing, brainstorming, answering questions, and more. "
                + "Everything runs locally on your device."
        ),
        ChatMessage(
            role: .user,
            content: "That's great! How does it work?"
        ),
        ChatMessage(
            role: .assistant,
            content: "I run a language model directly on your iPhone's processor. "
                + "You can download different models from the Models tab. "
                + "All inference happens on-device using your phone's GPU."
        ),
    ]
}
