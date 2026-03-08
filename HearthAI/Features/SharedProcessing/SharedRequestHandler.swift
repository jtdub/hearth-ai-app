import Foundation
import SwiftData

/// Handles incoming requests from the Share Extension via URL scheme.
@MainActor
@Observable
final class SharedRequestHandler {
    var pendingRequest: SharedInferenceRequest?
    var isProcessing = false
    var resultText: String?
    var errorMessage: String?

    func handleURL(_ url: URL) {
        guard url.scheme == AppGroupConstants.urlScheme,
              url.host == "process-shared",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let requestIdString = components.queryItems?
                .first(where: { $0.name == "requestId" })?.value,
              let requestId = UUID(uuidString: requestIdString) else {
            return
        }

        do {
            pendingRequest = try SharedInferenceRequest.load(id: requestId)
        } catch {
            errorMessage = "Failed to load shared request."
        }
    }

    func processRequest(
        inferenceService: InferenceService,
        context: ModelContext
    ) async {
        guard var request = pendingRequest else { return }

        isProcessing = true
        resultText = nil
        errorMessage = nil

        request.status = .processing

        do {
            let result = try await IntentInferenceHelper.run(
                prompt: request.inputText,
                systemPrompt: request.taskType.systemPrompt,
                modelId: request.modelId
            )

            request.status = .completed
            request.result = result.text
            resultText = result.text

            // Persist as a conversation
            persistResult(
                request: request, result: result.text, context: context
            )
        } catch {
            request.status = .failed
            errorMessage = error.localizedDescription
        }

        // Clean up the request file
        request.delete()
        isProcessing = false
    }

    func dismiss() {
        pendingRequest = nil
        resultText = nil
        errorMessage = nil
        isProcessing = false
    }

    private func persistResult(
        request: SharedInferenceRequest,
        result: String,
        context: ModelContext
    ) {
        let conversation = Conversation(
            title: String(request.inputText.prefix(50)),
            systemPrompt: request.taskType.systemPrompt
        )
        context.insert(conversation)

        let userMsg = Message(
            role: .user, content: request.inputText
        )
        userMsg.conversation = conversation
        conversation.messages.append(userMsg)

        let assistantMsg = Message(
            role: .assistant, content: result
        )
        assistantMsg.conversation = conversation
        conversation.messages.append(assistantMsg)

        try? context.save()
    }
}
