import Testing
@testable import HearthAI

@Test func inferenceConfigurationDefaults() {
    let config = InferenceConfiguration.default
    #expect(config.temperature == 0.7)
    #expect(config.topP == 0.9)
    #expect(config.maxTokens == 512)
    #expect(config.repeatPenalty == 1.1)
}

@Test func chatMessageCreation() {
    let msg = ChatMessage(role: .user, content: "Hello")
    #expect(msg.role == .user)
    #expect(msg.content == "Hello")
}

@Test func chatViewModelClear() {
    let vm = ChatViewModel()
    vm.messages.append(ChatMessage(role: .user, content: "test"))
    vm.clearMessages()
    #expect(vm.messages.isEmpty)
    #expect(vm.streamingText.isEmpty)
}
