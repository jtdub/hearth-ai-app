import Foundation
import SwiftData
import LlamaCpp

/// Runs inference for App Intents using LlamaContext directly.
/// Avoids MainActor dependency by working with the actor-isolated
/// LlamaContext.
enum IntentInferenceHelper {

    struct Result {
        let text: String
        let tokenCount: Int
    }

    static func run(
        prompt: String,
        systemPrompt: String,
        modelId: String?,
        maxTokens: Int32 = 256,
        temperature: Float = 0.7,
        topP: Float = 0.9
    ) async throws -> Result {
        let model = try await resolveModel(id: modelId)
        let modelPath = model.absolutePath

        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw IntentError.modelNotFound
        }

        let context = try LlamaContext(
            modelPath: modelPath.path,
            contextSize: 1024,
            gpuLayers: -1
        )

        let fullPrompt = buildPrompt(
            system: systemPrompt,
            user: prompt
        )

        var output = ""
        var tokenCount = 0
        let stopTokens = [
            "<|im_end|>", "<|im_start|>", "<|endoftext|>"
        ]

        let stream = await context.generate(
            prompt: fullPrompt,
            maxTokens: maxTokens,
            temperature: temperature,
            topP: topP,
            repeatPenalty: 1.1
        )

        for await token in stream {
            output += token
            tokenCount += 1

            if stopTokens.contains(where: { output.hasSuffix($0) }) {
                for stop in stopTokens where output.hasSuffix(stop) {
                    output = String(output.dropLast(stop.count))
                }
                await context.cancel()
                break
            }
        }

        for stop in stopTokens {
            output = output.replacingOccurrences(of: stop, with: "")
        }
        output = output.trimmingCharacters(in: .whitespacesAndNewlines)

        return Result(text: output, tokenCount: tokenCount)
    }

    @MainActor
    private static func resolveModel(id: String?) async throws -> LocalModel {
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        let container = try ModelContainer(
            for: LocalModel.self, Conversation.self, Message.self,
            configurations: config
        )
        let context = container.mainContext

        if let id {
            var descriptor = FetchDescriptor<LocalModel>(
                predicate: #Predicate { $0.id == id }
            )
            descriptor.fetchLimit = 1
            if let model = try context.fetch(descriptor).first {
                return model
            }
        }

        // Fall back to most recently used model
        var descriptor = FetchDescriptor<LocalModel>(
            sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let model = try context.fetch(descriptor).first else {
            throw IntentError.noModelAvailable
        }
        return model
    }

    private static func buildPrompt(
        system: String,
        user: String
    ) -> String {
        """
        <|im_start|>system
        \(system)<|im_end|>
        <|im_start|>user
        \(user)<|im_end|>
        <|im_start|>assistant
        """
    }
}

enum IntentError: Error, LocalizedError {
    case modelNotFound
    case noModelAvailable
    case inferenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            "The selected model file was not found on disk."
        case .noModelAvailable:
            "No AI model is downloaded. Open Hearth AI "
            + "and download a model first."
        case .inferenceFailed(let reason):
            "Inference failed: \(reason)"
        }
    }
}
