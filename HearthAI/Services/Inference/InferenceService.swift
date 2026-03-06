import Foundation
import LlamaCpp
import UIKit

@Observable
final class InferenceService {
    private(set) var loadedModelId: String?
    private(set) var isLoading = false
    private(set) var isGenerating = false
    private(set) var loadError: String?

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
        loadError = nil
        defer { isLoading = false }

        let path = model.absolutePath
        try validateModelFile(at: path, expected: model.fileSizeBytes)

        context = try LlamaContext(modelPath: path.path, contextSize: 2048, gpuLayers: -1)
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

    // MARK: - File Validation

    private func validateModelFile(at url: URL, expected: Int64) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw InferenceError.modelFileNotFound(url.lastPathComponent)
        }

        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let fileSize = attrs[.size] as? Int64 else {
            throw InferenceError.modelFileCorrupted(url.lastPathComponent)
        }

        if expected > 0 && fileSize != expected {
            throw InferenceError.modelFileSizeMismatch(
                expected: expected, actual: fileSize
            )
        }
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
        backgroundTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.backgroundUnloadTimeout,
            repeats: false
        ) { [weak self] _ in
            guard let self else { return }
            Task { await self.unloadModel() }
        }
    }

    private func cancelBackgroundUnloadTimer() {
        backgroundTimer?.invalidate()
        backgroundTimer = nil
    }
}

enum InferenceError: Error, LocalizedError {
    case modelFileNotFound(String)
    case modelFileCorrupted(String)
    case modelFileSizeMismatch(expected: Int64, actual: Int64)

    var errorDescription: String? {
        switch self {
        case .modelFileNotFound(let name):
            return "Model file not found: \(name)"
        case .modelFileCorrupted(let name):
            return "Model file appears corrupted: \(name)"
        case .modelFileSizeMismatch(let expected, let actual):
            let exp = ByteCountFormatter.string(fromByteCount: expected, countStyle: .file)
            let act = ByteCountFormatter.string(fromByteCount: actual, countStyle: .file)
            return "Model file size mismatch: expected \(exp), got \(act). The file may be corrupted."
        }
    }
}
