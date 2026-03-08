# Hearth AI

A multi-platform app (iOS, macOS, visionOS) for running large language models entirely on-device using [llama.cpp](https://github.com/ggerganov/llama.cpp). Browse and download GGUF models from Hugging Face Hub, then chat with them locally — no server, no API keys, fully private.

## Features

- **On-device inference** — Run GGUF models locally with Metal GPU acceleration
- **Model store** — Browse Hugging Face Hub, search for GGUF models, and see which ones fit your device's available memory
- **Background downloads** — Download models with pause/resume support via background URLSession
- **Conversation history** — Persistent chat history with SwiftData, multiple conversations, custom system prompts
- **Document Q&A** — Import documents (text, PDF, photos via OCR), chunk them, and ask questions with TF-IDF retrieval
- **Conversation memory** — Persistent personal knowledge base with TF-IDF relevance scoring, per-conversation toggle, and JSON export
- **Share Extension** — Process shared text and URLs from other apps using your local models
- **App Intents** — Siri and Shortcuts integration for asking questions, rewriting, translating, and summarizing text
- **Device-aware** — Automatically filters models by available RAM, warns on tight fits, blocks models too large for your device
- **Thermal management** — Monitors device temperature and pauses generation if the device overheats
- **Memory safety** — Auto-unloads models on memory warnings and after 60 seconds in the background
- **Multi-platform** — Runs on iOS, macOS, and visionOS with adaptive UI (tabs on compact, sidebar on regular)

## Requirements

- iOS 17.0+ / macOS 14.0+ / visionOS 1.0+
- Xcode 16.3+
- macOS 15+ (for building)

## Getting Started

### 1. Clone and initialize submodules

```bash
git clone --recursive https://github.com/jtdub/hearth-ai-app.git
cd hearth-ai-app
```

If you already cloned without `--recursive`:

```bash
git submodule update --init --recursive
```

### 2. Install dependencies

```bash
brew install xcodegen swiftlint
```

### 3. Build the llama.cpp XCFramework

This compiles llama.cpp into a universal XCFramework for iOS device and simulator:

```bash
bash scripts/build-xcframework.sh
```

### 4. Generate the Xcode project

The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) — the `.xcodeproj` is generated from `project.yml`:

```bash
xcodegen generate
```

### 5. Build and run

Open `HearthAI.xcodeproj` in Xcode, select a simulator or device, and run. Or from the command line:

```bash
# iOS
xcodebuild build -project HearthAI.xcodeproj -scheme HearthAI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO EXCLUDED_ARCHS='x86_64'

# macOS
xcodebuild build -project HearthAI.xcodeproj -scheme HearthAI \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

## Usage

1. **Download a model** — Go to the Models tab, pick a recommended model or search for one. The app shows which models are compatible with your device's memory.
2. **Load a model** — Tap the brain icon in Chat or go to the Library tab to load a downloaded model.
3. **Chat** — Switch to the Chat tab and start a conversation. Responses stream token-by-token.
4. **Import documents** — Go to the Documents tab to import text, PDFs, or photos (OCR). Attach a document to a conversation for Q&A.
5. **Manage memories** — Go to the Memory tab to add personal facts, preferences, and instructions that personalize conversations.
6. **Share Extension** — Share text or URLs from any app to process them with your local model.
7. **Shortcuts** — Use Siri or the Shortcuts app to ask Hearth AI questions, rewrite, translate, or summarize text.

### Recommended Models

| Model | Size | Best for |
|-------|------|----------|
| Qwen 2.5 0.5B | ~470 MB | Testing, low-memory devices |
| Llama 3.2 1B | ~776 MB | Fast inference on mobile |
| Qwen 2.5 1.5B | ~1.1 GB | Balance of speed and quality |
| Llama 3.2 3B | ~2 GB | Strong reasoning (6GB+ RAM) |
| Phi 3.5 Mini | ~2.2 GB | Excellent for its size (6GB+ RAM) |

## Architecture

**SwiftUI + MVVM** with `@Observable` view models and **SwiftData** for persistence.

```
HearthAI/
  App/            App entry point, AppState (DI container)
  Features/       Feature modules
    Chat/           Chat UI and view model
    ModelStore/     Model browsing and download
    Library/        Downloaded model management
    Documents/      Document import and management
    Memory/         Personal knowledge base management
    Settings/       App settings
    AppIntents/     Siri and Shortcuts integration
    SharedProcessing/  Shared text processing UI
  Models/         SwiftData models (LocalModel, Conversation, Message,
                    Document, DocumentChunk, Memory)
  Services/       Core services
    Inference/      LlamaContext wrapper, model loading, streaming generation
    Download/       Background URLSession download manager
    HuggingFace/    HF Hub REST API client
    Thermal/        Device thermal state monitoring
    DocumentProcessing/  Chunking and chunk selection services
    MemoryProcessing/    Memory selection with TF-IDF scoring
  Shared/         Constants, extensions, shared types
HearthAI ShareExtension/  Share Extension target
Packages/
  LlamaCpp/       Swift package wrapping llama.cpp via XCFramework
scripts/          Build and test helper scripts
```

### Key Design Decisions

- **Zero third-party Swift dependencies** — Only the vendored llama.cpp C++ library
- **XcodeGen** — Project file is generated from `project.yml`; edit that instead of the `.xcodeproj`
- **`@MainActor` services** — All `@Observable` services and view models are main-actor-isolated for thread safety
- **Background downloads** — Uses `URLSessionDownloadDelegate` with `NSLock`-protected task mapping for cross-isolation-domain safety
- **Metal GPU acceleration** — llama.cpp is linked with Metal, MetalPerformanceShaders, and Accelerate frameworks
- **App Group shared container** — SwiftData store lives in the App Group container so the Share Extension can access model data
- **TF-IDF retrieval** — Both document chunks and memories use TF-IDF scoring for relevance-based context injection within token budgets

## Development

### Running Tests

Uses the Swift Testing framework (`@Test` macro):

```bash
xcodebuild test -project HearthAI.xcodeproj -scheme HearthAI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO EXCLUDED_ARCHS='x86_64' \
  -only-testing:HearthAITests -parallel-testing-enabled YES
```

### Linting

```bash
swiftlint lint --strict
```

### Project Changes

Always edit `project.yml` for build settings or target changes, then regenerate:

```bash
xcodegen generate
```

## CI

GitHub Actions runs on every push and PR to `main`:

- **SwiftLint** — Strict mode with `github-actions-logging` reporter
- **Build & Test** — Builds the XCFramework, generates the project, compiles, and runs all tests on an iOS Simulator

## License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.

Note: The vendored [llama.cpp](https://github.com/ggerganov/llama.cpp) library has its own [MIT License](Packages/LlamaCpp/vendored/llama.cpp/LICENSE).
