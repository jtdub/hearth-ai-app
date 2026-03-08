import Foundation
import Testing
@testable import HearthAI

@Suite
struct SharedTypesTests {

    // MARK: - SharedModelInfo

    @Test func sharedModelInfoCodableRoundTrip() throws {
        let model = SharedModelInfo(
            id: "test/repo/model.gguf",
            displayName: "Test Model",
            modelFamily: "Llama",
            quantization: "Q4_K_M",
            fileSizeBytes: 4_000_000_000,
            localPath: "test_repo/model.gguf"
        )

        let data = try JSONEncoder().encode(model)
        let decoded = try JSONDecoder().decode(
            SharedModelInfo.self, from: data
        )

        #expect(decoded.id == model.id)
        #expect(decoded.displayName == model.displayName)
        #expect(decoded.modelFamily == model.modelFamily)
        #expect(decoded.quantization == model.quantization)
        #expect(decoded.fileSizeBytes == model.fileSizeBytes)
        #expect(decoded.localPath == model.localPath)
    }

    @Test func sharedModelInfoArrayCodable() throws {
        let models = [
            SharedModelInfo(
                id: "a", displayName: "Model A",
                modelFamily: "Llama", quantization: "Q4",
                fileSizeBytes: 1000, localPath: "a/model.gguf"
            ),
            SharedModelInfo(
                id: "b", displayName: "Model B",
                modelFamily: "Phi", quantization: "Q8",
                fileSizeBytes: 2000, localPath: "b/model.gguf"
            ),
        ]

        let data = try JSONEncoder().encode(models)
        let decoded = try JSONDecoder().decode(
            [SharedModelInfo].self, from: data
        )

        #expect(decoded.count == 2)
        #expect(decoded[0].id == "a")
        #expect(decoded[1].id == "b")
    }

    // MARK: - SharedInferenceRequest

    @Test func sharedInferenceRequestCreation() {
        let request = SharedInferenceRequest(
            inputText: "Hello world",
            taskType: .summarize,
            modelId: "test-model"
        )

        #expect(request.inputText == "Hello world")
        #expect(request.taskType == .summarize)
        #expect(request.modelId == "test-model")
        #expect(request.status == .pending)
        #expect(request.result == nil)
    }

    @Test func sharedInferenceRequestCodable() throws {
        var request = SharedInferenceRequest(
            inputText: "Translate this",
            taskType: .translate
        )
        request.status = .completed
        request.result = "Translated text"

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(
            SharedInferenceRequest.self, from: data
        )

        #expect(decoded.id == request.id)
        #expect(decoded.inputText == "Translate this")
        #expect(decoded.taskType == .translate)
        #expect(decoded.status == .completed)
        #expect(decoded.result == "Translated text")
    }

    @Test func taskTypeDisplayNames() {
        #expect(
            SharedInferenceRequest.TaskType.ask.displayName == "Ask"
        )
        #expect(
            SharedInferenceRequest.TaskType.summarize.displayName
                == "Summarize"
        )
        #expect(
            SharedInferenceRequest.TaskType.translate.displayName
                == "Translate"
        )
        #expect(
            SharedInferenceRequest.TaskType.rewrite.displayName
                == "Rewrite"
        )
        #expect(
            SharedInferenceRequest.TaskType.explain.displayName
                == "Explain"
        )
    }

    @Test func taskTypeSystemPrompts() {
        for taskType in SharedInferenceRequest.TaskType.allCases {
            #expect(!taskType.systemPrompt.isEmpty)
        }
    }

    @Test func requestStatusValues() throws {
        let statuses: [SharedInferenceRequest.RequestStatus] = [
            .pending, .processing, .completed, .failed,
        ]
        for status in statuses {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(
                SharedInferenceRequest.RequestStatus.self, from: data
            )
            #expect(decoded == status)
        }
    }

    // MARK: - AppGroupConstants

    @Test func appGroupConstantsValues() {
        #expect(AppGroupConstants.groupId == "group.ai.hearth.shared")
        #expect(AppGroupConstants.urlScheme == "hearth")
    }

    // MARK: - SharedRequestHandler

    @Test @MainActor func sharedRequestHandlerDismiss() {
        let handler = SharedRequestHandler()
        handler.pendingRequest = SharedInferenceRequest(
            inputText: "test", taskType: .ask
        )
        handler.resultText = "result"
        handler.errorMessage = "error"

        handler.dismiss()

        #expect(handler.pendingRequest == nil)
        #expect(handler.resultText == nil)
        #expect(handler.errorMessage == nil)
        #expect(handler.isProcessing == false)
    }

    @Test @MainActor func sharedRequestHandlerInvalidURL() throws {
        let handler = SharedRequestHandler()
        let url = try #require(URL(string: "https://example.com"))
        handler.handleURL(url)
        #expect(handler.pendingRequest == nil)
    }

    // MARK: - IntentError

    @Test func intentErrorDescriptions() {
        let notFound = IntentError.modelNotFound
        #expect(notFound.errorDescription?.contains("not found") == true)

        let noModel = IntentError.noModelAvailable
        #expect(noModel.errorDescription?.contains("No AI model") == true)

        let failed = IntentError.inferenceFailed("timeout")
        #expect(failed.errorDescription?.contains("timeout") == true)
    }
}
