/// llama_bridge.cpp — C bridge implementation for llama.cpp
///
/// This file provides the C-linkage functions declared in llama_bridge.h.
/// It wraps llama.cpp's C++ API into a simple create/generate/destroy lifecycle.
///
/// NOTE: This is a stub implementation. Once llama.cpp is vendored as a git
/// submodule in vendored/llama.cpp/, the #include paths and API calls below
/// should be updated to match the vendored version's headers.

#include "llama_bridge.h"
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

// ============================================================================
// Stub implementation
//
// This compiles and links without llama.cpp present, returning placeholder
// responses. Replace with real llama.cpp calls once the submodule is added.
// ============================================================================

struct llama_bridge_context {
    std::string model_path;
    int32_t n_ctx;
    int32_t n_gpu_layers;
    bool use_mmap;
    // TODO: Add llama_model* and llama_context* once llama.cpp is vendored
};

llama_bridge_context* llama_bridge_create(const char* model_path,
                                          int32_t n_ctx,
                                          int32_t n_gpu_layers,
                                          bool use_mmap) {
    if (!model_path) return nullptr;

    auto* ctx = new (std::nothrow) llama_bridge_context();
    if (!ctx) return nullptr;

    ctx->model_path = model_path;
    ctx->n_ctx = n_ctx;
    ctx->n_gpu_layers = n_gpu_layers;
    ctx->use_mmap = use_mmap;

    // TODO: Replace with actual llama.cpp model loading:
    // llama_model_params model_params = llama_model_default_params();
    // model_params.n_gpu_layers = n_gpu_layers;
    // model_params.use_mmap = use_mmap;
    // ctx->model = llama_load_model_from_file(model_path, model_params);
    // if (!ctx->model) { delete ctx; return nullptr; }
    //
    // llama_context_params ctx_params = llama_context_default_params();
    // ctx_params.n_ctx = n_ctx;
    // ctx->llama_ctx = llama_new_context_with_model(ctx->model, ctx_params);

    return ctx;
}

void llama_bridge_destroy(llama_bridge_context* ctx) {
    if (!ctx) return;

    // TODO: Replace with actual cleanup:
    // llama_free(ctx->llama_ctx);
    // llama_free_model(ctx->model);

    delete ctx;
}

int32_t llama_bridge_generate(llama_bridge_context* ctx,
                              const char* prompt,
                              int32_t max_tokens,
                              float temperature,
                              float top_p,
                              float repeat_penalty,
                              llama_bridge_token_callback callback,
                              void* user_data,
                              volatile bool* cancel_flag) {
    if (!ctx || !prompt || !callback) return -1;

    // TODO: Replace this stub with actual llama.cpp inference.
    // The real implementation will:
    // 1. Tokenize the prompt
    // 2. Evaluate prompt tokens in batches
    // 3. Sample tokens one at a time
    // 4. Call callback() for each token piece
    // 5. Check cancel_flag between tokens
    // 6. Stop on EOS or max_tokens

    // Stub: emit a placeholder response token by token
    const char* stub_response = "Hello! I'm a stub response from the llama bridge. "
                                "Once llama.cpp is integrated, I'll provide real AI responses. "
                                "This confirms the bridge layer is working correctly.";

    int32_t tokens_generated = 0;
    const char* p = stub_response;

    while (*p != '\0' && tokens_generated < max_tokens) {
        if (cancel_flag && *cancel_flag) break;

        // Emit one word at a time as a "token"
        std::string token;
        while (*p != '\0' && *p != ' ') {
            token += *p++;
        }
        if (*p == ' ') {
            token += ' ';
            p++;
        }

        callback(token.c_str(), user_data);
        tokens_generated++;
    }

    return tokens_generated;
}

int32_t llama_bridge_context_size(llama_bridge_context* ctx) {
    if (!ctx) return 0;
    return ctx->n_ctx;
}

int64_t llama_bridge_model_size(llama_bridge_context* ctx) {
    if (!ctx) return 0;
    // TODO: Return actual model size from llama.cpp
    return 0;
}
