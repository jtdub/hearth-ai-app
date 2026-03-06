#ifndef LLAMA_BRIDGE_H
#define LLAMA_BRIDGE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Opaque context handle wrapping llama.cpp model and context.
typedef struct llama_bridge_context llama_bridge_context;

/// Callback invoked for each generated token.
/// @param token Null-terminated UTF-8 string for the token piece.
/// @param user_data Pointer passed through from the generate call.
typedef void (*llama_bridge_token_callback)(const char* token, void* user_data);

/// Load a GGUF model and create an inference context.
/// @param model_path Path to the .gguf file.
/// @param n_ctx Context size in tokens (e.g. 2048).
/// @param n_gpu_layers Number of layers to offload to GPU (-1 for all).
/// @param use_mmap Whether to memory-map the model file.
/// @return Context handle, or NULL on failure.
llama_bridge_context* llama_bridge_create(const char* model_path,
                                          int32_t n_ctx,
                                          int32_t n_gpu_layers,
                                          bool use_mmap);

/// Free all resources associated with a context.
void llama_bridge_destroy(llama_bridge_context* ctx);

/// Run text generation with streaming token output.
/// @param ctx Context handle from llama_bridge_create.
/// @param prompt The input prompt string.
/// @param max_tokens Maximum number of tokens to generate.
/// @param temperature Sampling temperature (0.0 = greedy).
/// @param top_p Nucleus sampling threshold.
/// @param repeat_penalty Repetition penalty factor.
/// @param callback Function called for each generated token.
/// @param user_data Opaque pointer passed to callback.
/// @param cancel_flag Pointer to a bool; set to true to stop generation.
/// @return Number of tokens generated, or -1 on error.
int32_t llama_bridge_generate(llama_bridge_context* ctx,
                              const char* prompt,
                              int32_t max_tokens,
                              float temperature,
                              float top_p,
                              float repeat_penalty,
                              llama_bridge_token_callback callback,
                              void* user_data,
                              volatile bool* cancel_flag);

/// Get the context size (max tokens) for the loaded model.
int32_t llama_bridge_context_size(llama_bridge_context* ctx);

/// Get the model size in bytes.
int64_t llama_bridge_model_size(llama_bridge_context* ctx);

#ifdef __cplusplus
}
#endif

#endif /* LLAMA_BRIDGE_H */
