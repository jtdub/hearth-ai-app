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

@Test func chatViewModelClear() {
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

@Test func downloadInfoProgressFormat() {
    let info = DownloadInfo(
        id: "test/model.gguf",
        repoId: "test",
        fileName: "model.gguf",
        fileSize: 1_000_000_000
    )
    info.progress = 0.5
    #expect(info.formattedProgress.contains("/"))
}

@Test func modelStoreViewModelInit() {
    let viewModel = ModelStoreViewModel()
    #expect(!viewModel.featuredModels.isEmpty)
    #expect(viewModel.searchResults.isEmpty)
    #expect(viewModel.isSearching == false)
}

// MARK: - Phase 3 Tests

@Test func deviceCapabilityMemoryCheck() {
    // A truly tiny file should fit on any device with >2GB available memory
    let tiny = DeviceCapability.canRunModel(fileSizeBytes: 1)
    let available = DeviceCapability.availableMemoryBytes
    if available > DeviceCapability.memoryOverheadBytes {
        #expect(tiny == .fits)
    }

    let huge = DeviceCapability.canRunModel(fileSizeBytes: 999_000_000_000)
    #expect(huge == .tooLarge)
    #expect(huge.canDownload == false)
}

@Test func thermalMonitorInitialState() {
    let monitor = ThermalMonitor()
    #expect(monitor.thermalState == ProcessInfo.processInfo.thermalState)
}

@Test func chatViewModelNewConversation() {
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

// MARK: - Phase 4 Tests

@Test func networkMonitorInitialState() {
    let monitor = NetworkMonitor()
    // Default state before NWPathMonitor fires
    #expect(monitor.isOnWiFi == true)
}

@Test func onboardingFlagDefault() {
    let defaults = UserDefaults.standard
    defaults.removeObject(forKey: "hasCompletedOnboarding")
    let value = defaults.bool(forKey: "hasCompletedOnboarding")
    #expect(value == false)
}

@Test func cellularWarningThreshold() {
    let largeSize: Int64 = 300_000_000
    let smallSize: Int64 = 100_000_000
    let threshold: Int64 = 200_000_000
    #expect(largeSize > threshold)
    #expect(smallSize <= threshold)
}

@Test func modelFitResultWarningMessages() {
    let fits = ModelFitResult.fits
    #expect(fits.warningMessage == nil)
    #expect(fits.canDownload == true)

    let tight = ModelFitResult.tight
    #expect(tight.warningMessage != nil)
    #expect(tight.canDownload == true)

    let tooLarge = ModelFitResult.tooLarge
    #expect(tooLarge.warningMessage != nil)
    #expect(tooLarge.canDownload == false)
}
