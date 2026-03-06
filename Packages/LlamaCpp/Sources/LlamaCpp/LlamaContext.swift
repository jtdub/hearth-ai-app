import CLlama
import Foundation

/// Thread-safe wrapper around the llama.cpp C bridge.
///
/// Uses Swift actor isolation to serialize access to the underlying C context.
/// Tokens are streamed via `AsyncStream<String>` for natural integration with SwiftUI.
public actor LlamaContext {
    private var context: OpaquePointer?
    private let cancelFlag: UnsafeMutablePointer<Bool>

    /// Load a GGUF model file and prepare for inference.
    /// - Parameters:
    ///   - modelPath: Absolute path to the .gguf file.
    ///   - contextSize: Maximum context length in tokens.
    ///   - gpuLayers: Number of layers to offload to Metal GPU. Use -1 for all layers.
    public init(modelPath: String, contextSize: Int32 = 2048, gpuLayers: Int32 = -1) throws {
        cancelFlag = .allocate(capacity: 1)
        cancelFlag.pointee = false

        guard let ctx = llama_bridge_create(modelPath, contextSize, gpuLayers, true) else {
            cancelFlag.deallocate()
            throw LlamaError.failedToLoadModel(path: modelPath)
        }
        self.context = ctx
    }

    deinit {
        if let context {
            llama_bridge_destroy(context)
        }
        cancelFlag.deallocate()
    }

    /// Generate text from a prompt, streaming tokens as they are produced.
    /// - Returns: An `AsyncStream` that yields individual token strings.
    public func generate(
        prompt: String,
        maxTokens: Int32 = 512,
        temperature: Float = 0.7,
        topP: Float = 0.9,
        repeatPenalty: Float = 1.1
    ) -> AsyncStream<String> {
        cancelFlag.pointee = false
        let ctx = self.context
        let flag = self.cancelFlag

        return AsyncStream { continuation in
            let callbackContext = Unmanaged.passRetained(
                TokenCallbackBox(continuation: continuation)
            ).toOpaque()

            Task.detached(priority: .userInitiated) {
                llama_bridge_generate(
                    ctx,
                    prompt,
                    maxTokens,
                    temperature,
                    topP,
                    repeatPenalty,
                    { tokenCStr, userData in
                        guard let userData, let tokenCStr else { return }
                        let box = Unmanaged<TokenCallbackBox>
                            .fromOpaque(userData)
                            .takeUnretainedValue()
                        box.continuation.yield(String(cString: tokenCStr))
                    },
                    callbackContext,
                    flag
                )

                Unmanaged<TokenCallbackBox>.fromOpaque(callbackContext).release()
                continuation.finish()
            }
        }
    }

    /// Signal the inference loop to stop after the current token.
    public func cancel() {
        cancelFlag.pointee = true
    }

    /// The configured context size in tokens.
    public var contextSize: Int32 {
        guard let context else { return 0 }
        return llama_bridge_context_size(context)
    }

    /// The loaded model's size in bytes.
    public var modelSize: Int64 {
        guard let context else { return 0 }
        return llama_bridge_model_size(context)
    }
}

/// Boxes the AsyncStream continuation so it can be passed through a C void* pointer.
private final class TokenCallbackBox: @unchecked Sendable {
    let continuation: AsyncStream<String>.Continuation

    init(continuation: AsyncStream<String>.Continuation) {
        self.continuation = continuation
    }
}

/// Errors from the llama.cpp bridge layer.
public enum LlamaError: Error, LocalizedError {
    case failedToLoadModel(path: String)
    case inferenceError(String)

    public var errorDescription: String? {
        switch self {
        case .failedToLoadModel(let path):
            "Failed to load model at: \(path)"
        case .inferenceError(let message):
            "Inference error: \(message)"
        }
    }
}
