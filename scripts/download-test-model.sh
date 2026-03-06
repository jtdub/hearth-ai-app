#!/usr/bin/env bash
#
# Downloads a small GGUF model for Phase 1 testing.
# The model is stored in the project's models/ directory for on-device testing.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODELS_DIR="$PROJECT_ROOT/models"

# Qwen2.5-0.5B-Instruct — small model (~469MB), publicly accessible, no auth required
MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf"
MODEL_FILE="qwen2.5-0.5b-instruct-q4_k_m.gguf"

mkdir -p "$MODELS_DIR"

if [ -f "$MODELS_DIR/$MODEL_FILE" ]; then
    echo "Model already exists: $MODELS_DIR/$MODEL_FILE"
    echo "Size: $(du -h "$MODELS_DIR/$MODEL_FILE" | cut -f1)"
    exit 0
fi

echo "=== Downloading test model ==="
echo "Model: Qwen2.5-0.5B-Instruct (Q4_K_M, ~469MB)"
echo "URL: $MODEL_URL"
echo "Destination: $MODELS_DIR/$MODEL_FILE"
echo ""

curl -L --progress-bar -o "$MODELS_DIR/$MODEL_FILE" "$MODEL_URL"

# Verify it's actually a GGUF file (starts with "GGUF" magic bytes)
if ! head -c 4 "$MODELS_DIR/$MODEL_FILE" | grep -q "GGUF"; then
    echo "Error: Downloaded file is not a valid GGUF model"
    rm -f "$MODELS_DIR/$MODEL_FILE"
    exit 1
fi

echo ""
echo "=== Download complete ==="
echo "Size: $(du -h "$MODELS_DIR/$MODEL_FILE" | cut -f1)"
echo ""
echo "To test on a physical device, use Xcode to copy this file to the app's"
echo "Application Support/Models/ directory, or load it via the app UI."
