import Foundation
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

@Test @MainActor func chatViewModelClear() {
    let viewModel = ChatViewModel()
    viewModel.messages.append(ChatMessage(role: .user, content: "test"))
    viewModel.clearMessages()
    #expect(viewModel.messages.isEmpty)
    #expect(viewModel.streamingText.isEmpty)
}

// MARK: - Phase 2 Tests

@Test func hfFileInfoGGUFDetection() {
    let ggufFile = HFFileInfo(type: "file", path: "model-q4_k_m.gguf", size: 1000)
    let otherFile = HFFileInfo(type: "file", path: "README.md", size: 500)

    #expect(ggufFile.isGGUF == true)
    #expect(otherFile.isGGUF == false)
}

@Test func hfFileInfoQuantizationParsing() {
    let file = HFFileInfo(type: "file", path: "llama-3.2-1b-q4_k_m.gguf", size: 1000)
    #expect(file.quantization == "Q4_K_M")

    let file2 = HFFileInfo(type: "file", path: "model-q8_0.gguf", size: 2000)
    #expect(file2.quantization == "Q8_0")
}

@Test func featuredModelsLoad() {
    let models = FeaturedModel.loadFeatured()
    #expect(!models.isEmpty)
    #expect(models.first?.repoId.contains("/") == true)
}

@Test @MainActor func downloadInfoProgressFormat() {
    let info = DownloadInfo(
        id: "test/model.gguf",
        repoId: "test",
        fileName: "model.gguf",
        fileSize: 1_000_000_000
    )
    info.progress = 0.5
    #expect(info.formattedProgress.contains("/"))
}

@Test @MainActor func modelStoreViewModelInit() {
    let viewModel = ModelStoreViewModel()
    #expect(!viewModel.featuredModels.isEmpty)
    #expect(viewModel.searchResults.isEmpty)
    #expect(viewModel.isSearching == false)
}

// MARK: - Phase 3 Tests

@Test func deviceCapabilityMemoryCheck() {
    let small = DeviceCapability.canRunModel(fileSizeBytes: 100_000)
    #expect(small == .fits)

    let huge = DeviceCapability.canRunModel(fileSizeBytes: 999_000_000_000)
    #expect(huge == .tooLarge)
    #expect(huge.canDownload == false)
}

@Test @MainActor func thermalMonitorInitialState() {
    let monitor = ThermalMonitor()
    #expect(monitor.thermalState == ProcessInfo.processInfo.thermalState)
}

@Test @MainActor func chatViewModelNewConversation() {
    let viewModel = ChatViewModel()
    viewModel.messages.append(ChatMessage(role: .user, content: "test"))
    viewModel.newConversation()
    #expect(viewModel.messages.isEmpty)
    #expect(viewModel.activeConversation == nil)
}

@Test func inferenceErrorDescriptions() {
    let notFound = InferenceError.modelFileNotFound("test.gguf")
    #expect(notFound.localizedDescription.contains("test.gguf"))

    let mismatch = InferenceError.modelFileSizeMismatch(expected: 1000, actual: 500)
    #expect(mismatch.localizedDescription.contains("mismatch"))
}
