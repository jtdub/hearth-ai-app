import Foundation
import LlamaCpp
import UIKit

/// Manages model loading/unloading and provides the inference API to the app.
@Observable
final class InferenceService {
    private(set) var loadedModelId: String?
    private(set) var isLoading = false
    private(set) var isGenerating = false

    private var context: LlamaContext?
    private var backgroundTimer: Timer?

    init() {
        setupMemoryWarningObserver()
        setupBackgroundObservers()
    }

    // MARK: - Model Lifecycle

    func loadModel(_ model: LocalModel) async throws {
        await unloadModel()
        isLoading = true
        defer { isLoading = false }

        let path = model.absolutePath.path
        context = try LlamaContext(modelPath: path, contextSize: 2048, gpuLayers: -1)
        loadedModelId = model.id
    }

    func unloadModel() async {
        if let context {
            await context.cancel()
        }
        context = nil
        loadedModelId = nil
        isGenerating = false
    }

    var isModelLoaded: Bool {
        context != nil
    }

    // MARK: - Inference

    func generate(prompt: String, config: InferenceConfiguration) -> AsyncStream<String>? {
        guard let context else { return nil }
        isGenerating = true

        let stream = AsyncStream<String> { continuation in
            Task {
                let tokenStream = await context.generate(
                    prompt: prompt,
                    maxTokens: config.maxTokens,
                    temperature: config.temperature,
                    topP: config.topP,
                    repeatPenalty: config.repeatPenalty
                )

                for await token in tokenStream {
                    continuation.yield(token)
                }

                continuation.finish()
                await MainActor.run { self.isGenerating = false }
            }
        }

        return stream
    }

    func cancelGeneration() async {
        await context?.cancel()
        isGenerating = false
    }

    // MARK: - Memory Management

    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { await self.unloadModel() }
        }
    }

    private func setupBackgroundObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.startBackgroundUnloadTimer()
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cancelBackgroundUnloadTimer()
        }
    }

    private func startBackgroundUnloadTimer() {
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { await self.unloadModel() }
        }
    }

    private func cancelBackgroundUnloadTimer() {
        backgroundTimer?.invalidate()
        backgroundTimer = nil
    }
}
