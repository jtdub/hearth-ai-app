import Foundation
import Testing
@testable import HearthAI

// MARK: - TimeoutState Tests

@Test func timeoutStateInitialValues() {
    let state = TimeoutState()
    let info = state.currentState()
    #expect(!info.receivedFirstToken)
    #expect(!state.didTimeout)
}

@Test func timeoutStateRecordToken() {
    let state = TimeoutState()
    let before = Date()
    state.recordToken()
    let info = state.currentState()
    #expect(info.receivedFirstToken)
    #expect(info.lastTokenTime >= before)
}

@Test func timeoutStateMultipleTokens() {
    let state = TimeoutState()
    state.recordToken()
    let first = state.currentState().lastTokenTime
    Thread.sleep(forTimeInterval: 0.01)
    state.recordToken()
    let second = state.currentState().lastTokenTime
    #expect(second > first)
}

@Test func timeoutStateMarkTimeout() {
    let state = TimeoutState()
    #expect(!state.didTimeout)
    state.markTimeout()
    #expect(state.didTimeout)
}

@Test func timeoutStateConcurrentAccess() async {
    let state = TimeoutState()

    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<100 {
            group.addTask { state.recordToken() }
            group.addTask { _ = state.currentState() }
        }
    }

    let info = state.currentState()
    #expect(info.receivedFirstToken)
}

// MARK: - InferenceError Tests

@Test func insufficientMemoryErrorDescription() {
    let error = InferenceError.insufficientMemory(
        modelSize: "8 GB", available: "4 GB"
    )
    let desc = error.errorDescription ?? ""
    #expect(desc.contains("8 GB"))
    #expect(desc.contains("4 GB"))
    #expect(desc.contains("approximately"))
}

@Test func allInferenceErrorsHaveDescriptions() {
    let errors: [InferenceError] = [
        .modelFileNotFound("test.gguf"),
        .modelFileCorrupted("test.gguf"),
        .modelFileSizeMismatch(expected: 100, actual: 50),
        .insufficientMemory(
            modelSize: "8 GB", available: "4 GB"
        )
    ]
    for error in errors {
        let desc = error.errorDescription
        #expect(desc != nil)
        #expect(desc?.isEmpty == false)
    }
}

// MARK: - Constants Tests

@Test func inferenceTimeoutConstants() {
    #expect(Constants.firstTokenTimeoutSeconds > 0)
    #expect(Constants.interTokenTimeoutSeconds > 0)
    #expect(
        Constants.firstTokenTimeoutSeconds
            > Constants.interTokenTimeoutSeconds
    )
}

@Test func firstTokenTimeoutIsGenerous() {
    #expect(Constants.firstTokenTimeoutSeconds >= 60)
}

@Test func interTokenTimeoutIsReasonable() {
    #expect(Constants.interTokenTimeoutSeconds >= 10)
    #expect(Constants.interTokenTimeoutSeconds <= 120)
}

// MARK: - ChatViewModel Tests

@Test @MainActor func chatViewModelInferenceErrorDefault() {
    let viewModel = ChatViewModel()
    #expect(viewModel.inferenceError == nil)
}

@Test @MainActor func chatViewModelInferenceErrorCanBeSet() {
    let viewModel = ChatViewModel()
    viewModel.inferenceError = "Test error"
    #expect(viewModel.inferenceError == "Test error")
}

@Test @MainActor func chatViewModelInferenceErrorCanBeCleared() {
    let viewModel = ChatViewModel()
    viewModel.inferenceError = "Test error"
    viewModel.inferenceError = nil
    #expect(viewModel.inferenceError == nil)
}

@Test @MainActor func chatViewModelBuildPromptEmpty() {
    let viewModel = ChatViewModel()
    let prompt = viewModel.buildPrompt()
    #expect(prompt.contains("<|im_start|>system"))
    #expect(prompt.contains("helpful assistant"))
    #expect(prompt.contains("<|im_start|>assistant"))
}

@Test @MainActor func chatViewModelBuildPromptWithMessages() {
    let viewModel = ChatViewModel()
    viewModel.messages.append(
        ChatMessage(role: .user, content: "Hello")
    )
    viewModel.messages.append(
        ChatMessage(role: .assistant, content: "Hi there")
    )
    let prompt = viewModel.buildPrompt()
    #expect(prompt.contains("Hello"))
    #expect(prompt.contains("Hi there"))
    #expect(prompt.contains("<|im_start|>user"))
    #expect(prompt.contains("<|im_start|>assistant"))
}

// MARK: - DeviceCapability Load Check Tests

@Test func tooLargeModelCannotLoad() {
    let result = DeviceCapability.canRunModel(
        fileSizeBytes: 999_000_000_000_000
    )
    #expect(result == .tooLarge)
    #expect(!result.canDownload)
}

@Test func smallModelCanLoad() {
    let result = DeviceCapability.canRunModel(
        fileSizeBytes: 1_000_000
    )
    #expect(result != .tooLarge)
    #expect(result.canDownload)
}
