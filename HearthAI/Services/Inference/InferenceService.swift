import Foundation
import LlamaCpp
#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Observable
final class InferenceService {
    private(set) var loadedModelId: String?
    private(set) var isLoading = false
    private(set) var isGenerating = false
    private(set) var loadError: String?

    private var context: LlamaContext?
    private nonisolated(unsafe) var notificationObservers: [Any] = []
    #if os(macOS)
    private nonisolated(unsafe) var memoryPressureSource: DispatchSourceMemoryPressure?
    #endif

    init() {
        setupMemoryWarningObserver()
        setupBackgroundObservers()
    }

    deinit {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        backgroundTask?.cancel()
        #if os(macOS)
        memoryPressureSource?.cancel()
        #endif
    }

    // MARK: - Model Lifecycle

    func loadModel(_ model: LocalModel) async throws {
        let fit = DeviceCapability.canRunModel(
            fileSizeBytes: model.fileSizeBytes
        )
        if fit == .tooLarge {
            throw InferenceError.insufficientMemory(
                modelSize: ByteCountFormatter.string(
                    fromByteCount: model.fileSizeBytes,
                    countStyle: .file
                ),
                available: DeviceCapability.availableMemoryFormatted
            )
        }

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
        if isGenerating {
            await cancelGeneration()
        }
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
            Task.detached { [weak self] in
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
                await MainActor.run { [weak self] in self?.isGenerating = false }
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
        #if canImport(UIKit)
        let observer = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.unloadModel() }
        }
        notificationObservers.append(observer)
        #elseif os(macOS)
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            Task { @MainActor in await self.unloadModel() }
        }
        source.resume()
        memoryPressureSource = source
        #endif
    }

    private func setupBackgroundObservers() {
        #if canImport(UIKit)
        let bgObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.startBackgroundUnloadTimer() }
        }
        notificationObservers.append(bgObserver)

        let fgObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.cancelBackgroundUnloadTimer() }
        }
        notificationObservers.append(fgObserver)
        #endif
        // macOS: no background unload — apps don't suspend like iOS
    }

    private nonisolated(unsafe) var backgroundTask: Task<Void, Never>?

    private func startBackgroundUnloadTimer() {
        backgroundTask?.cancel()
        backgroundTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Constants.backgroundUnloadTimeout))
            guard !Task.isCancelled else { return }
            await self?.unloadModel()
        }
    }

    private func cancelBackgroundUnloadTimer() {
        backgroundTask?.cancel()
        backgroundTask = nil
    }
}

enum InferenceError: Error, LocalizedError {
    case modelFileNotFound(String)
    case modelFileCorrupted(String)
    case modelFileSizeMismatch(expected: Int64, actual: Int64)
    case insufficientMemory(modelSize: String, available: String)

    var errorDescription: String? {
        switch self {
        case .modelFileNotFound(let name):
            return "Model file not found: \(name)"
        case .modelFileCorrupted(let name):
            return "Model file appears corrupted: \(name)"
        case .modelFileSizeMismatch(let expected, let actual):
            let exp = ByteCountFormatter.string(
                fromByteCount: expected, countStyle: .file
            )
            let act = ByteCountFormatter.string(
                fromByteCount: actual, countStyle: .file
            )
            return "Model file size mismatch: expected \(exp),"
                + " got \(act). The file may be corrupted."
        case .insufficientMemory(let modelSize, let available):
            return "This model requires approximately"
                + " \(modelSize) but only \(available)"
                + " is available."
        }
    }
}
