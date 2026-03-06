import Foundation
import llama

/// Thread-safe wrapper around the llama.cpp C API.
///
/// Uses Swift actor isolation to serialize access to the underlying C context.
/// Tokens are streamed via `AsyncStream<String>` for natural integration with SwiftUI.
public actor LlamaContext {
    private var model: OpaquePointer
    private var context: OpaquePointer
    private var vocab: OpaquePointer
    private var batch: llama_batch
    private var isCancelled = false

    /// Temporary buffer for multi-byte UTF-8 sequences that span tokens.
    private var temporaryInvalidCChars: [CChar] = []

    public init(modelPath: String, contextSize: Int32 = 2048, gpuLayers: Int32 = -1) throws {
        llama_backend_init()

        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = gpuLayers

        #if targetEnvironment(simulator)
        modelParams.n_gpu_layers = 0
        #endif

        guard let model = llama_model_load_from_file(modelPath, modelParams) else {
            throw LlamaError.failedToLoadModel(path: modelPath)
        }
        self.model = model
        self.vocab = llama_model_get_vocab(model)

        let nThreads = Int32(max(1, min(8, ProcessInfo.processInfo.processorCount - 2)))

        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = UInt32(contextSize)
        ctxParams.n_threads = nThreads
        ctxParams.n_threads_batch = nThreads

        guard let context = llama_init_from_model(model, ctxParams) else {
            llama_model_free(model)
            throw LlamaError.failedToLoadModel(path: modelPath)
        }
        self.context = context
        self.batch = llama_batch_init(512, 0, 1)
    }

    deinit {
        llama_batch_free(batch)
        llama_model_free(model)
        llama_free(context)
        llama_backend_free()
    }

    /// Generate text from a prompt, streaming tokens as they are produced.
    public func generate(
        prompt: String,
        maxTokens: Int32 = 512,
        temperature: Float = 0.7,
        topP: Float = 0.9,
        repeatPenalty: Float = 1.1
    ) -> AsyncStream<String> {
        isCancelled = false

        return AsyncStream { continuation in
            Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                await self.runInference(
                    prompt: prompt,
                    maxTokens: maxTokens,
                    temperature: temperature,
                    topP: topP,
                    repeatPenalty: repeatPenalty,
                    continuation: continuation
                )
            }
        }
    }

    /// Signal the inference loop to stop after the current token.
    public func cancel() {
        isCancelled = true
    }

    /// The configured context size in tokens.
    public var contextSize: Int32 {
        Int32(llama_n_ctx(context))
    }

    /// The loaded model's size in bytes.
    public var modelSize: Int64 {
        Int64(llama_model_size(model))
    }

    // MARK: - Private Inference

    // swiftlint:disable:next function_parameter_count
    private func runInference(
        prompt: String,
        maxTokens: Int32,
        temperature: Float,
        topP: Float,
        repeatPenalty: Float,
        continuation: AsyncStream<String>.Continuation
    ) {
        // Tokenize
        let tokens = tokenize(text: prompt, addBos: true)

        // Clear KV cache
        llama_memory_clear(llama_get_memory(context), false)

        // Fill batch with prompt tokens
        batchClear()
        for (index, token) in tokens.enumerated() {
            batchAdd(token: token, pos: Int32(index), seqIds: [0], logits: false)
        }
        // Enable logits for last prompt token
        batch.logits[Int(batch.n_tokens) - 1] = 1

        if llama_decode(context, batch) != 0 {
            continuation.finish()
            return
        }

        var nCur = batch.n_tokens

        // Set up sampler chain
        let sparams = llama_sampler_chain_default_params()
        guard let sampler = llama_sampler_chain_init(sparams) else {
            continuation.finish()
            return
        }
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(temperature))
        llama_sampler_chain_add(sampler, llama_sampler_init_top_p(topP, 1))
        llama_sampler_chain_add(sampler, llama_sampler_init_penalties(
            Int32(tokens.count), repeatPenalty, 0.0, 0.0
        ))
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(UInt32.random(in: 0...UInt32.max)))
        defer { llama_sampler_free(sampler) }

        temporaryInvalidCChars = []

        // Generation loop
        for _ in 0..<maxTokens {
            if isCancelled { break }

            let newTokenId = llama_sampler_sample(sampler, context, batch.n_tokens - 1)

            if llama_vocab_is_eog(vocab, newTokenId) {
                break
            }

            // Convert token to text, handling multi-byte UTF-8
            let piece = tokenToPiece(token: newTokenId)
            temporaryInvalidCChars.append(contentsOf: piece)

            if let string = String(validatingUTF8: temporaryInvalidCChars + [0]) {
                temporaryInvalidCChars.removeAll()
                continuation.yield(string)
            }

            // Prepare next decode
            batchClear()
            batchAdd(token: newTokenId, pos: nCur, seqIds: [0], logits: true)
            nCur += 1

            if llama_decode(context, batch) != 0 {
                break
            }
        }

        // Flush any remaining bytes
        if !temporaryInvalidCChars.isEmpty {
            let remaining = String(cString: temporaryInvalidCChars + [0])
            if !remaining.isEmpty {
                continuation.yield(remaining)
            }
            temporaryInvalidCChars.removeAll()
        }

        continuation.finish()
    }

    // MARK: - Tokenization

    private func tokenize(text: String, addBos: Bool) -> [llama_token] {
        let utf8Count = text.utf8.count
        let nTokens = utf8Count + (addBos ? 1 : 0) + 1
        let tokens = UnsafeMutablePointer<llama_token>.allocate(capacity: nTokens)
        defer { tokens.deallocate() }

        let count = llama_tokenize(vocab, text, Int32(utf8Count), tokens, Int32(nTokens), addBos, false)
        return (0..<Int(count)).map { tokens[$0] }
    }

    private func tokenToPiece(token: llama_token) -> [CChar] {
        let bufSize = 8
        let result = UnsafeMutablePointer<Int8>.allocate(capacity: bufSize)
        result.initialize(repeating: 0, count: bufSize)
        defer { result.deallocate() }

        let nTokens = llama_token_to_piece(vocab, token, result, Int32(bufSize), 0, false)

        if nTokens < 0 {
            let newSize = Int(-nTokens)
            let newResult = UnsafeMutablePointer<Int8>.allocate(capacity: newSize)
            newResult.initialize(repeating: 0, count: newSize)
            defer { newResult.deallocate() }
            let nNew = llama_token_to_piece(vocab, token, newResult, Int32(newSize), 0, false)
            return Array(UnsafeBufferPointer(start: newResult, count: Int(nNew)))
        }
        return Array(UnsafeBufferPointer(start: result, count: Int(nTokens)))
    }

    // MARK: - Batch Helpers

    private func batchClear() {
        batch.n_tokens = 0
    }

    private func batchAdd(token: llama_token, pos: llama_pos, seqIds: [llama_seq_id], logits: Bool) {
        let idx = Int(batch.n_tokens)
        batch.token[idx] = token
        batch.pos[idx] = pos
        batch.n_seq_id[idx] = Int32(seqIds.count)
        if let seqIdPtr = batch.seq_id[idx] {
            for (seqIdx, seqId) in seqIds.enumerated() {
                seqIdPtr[seqIdx] = seqId
            }
        }
        batch.logits[idx] = logits ? 1 : 0
        batch.n_tokens += 1
    }
}

/// Errors from the llama.cpp layer.
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
