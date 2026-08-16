# Hearth AI

Hearth AI is a multi-platform app for iOS, macOS, and visionOS. It runs large language models fully on your device with [llama.cpp](https://github.com/ggerganov/llama.cpp). You can browse and download GGUF models from Hugging Face Hub. Then you can chat with the models locally. The app uses no server and no API keys. Your data stays private.

## Features

- **On-device inference** — Run GGUF models locally with Metal GPU acceleration
- **Model store** — Browse Hugging Face Hub, search for GGUF models, and see which models fit the available memory of your device
- **Background downloads** — Download models with a background URLSession; you can pause and resume downloads
- **Conversation history** — Keep chat history with SwiftData, with multiple conversations and custom system prompts
- **Document Q&A** — Import documents (text, PDF, photos with OCR), split them into chunks, and ask questions with TF-IDF retrieval
- **Conversation memory** — Keep a personal knowledge base with TF-IDF relevance scores, a toggle for each conversation, and JSON export
- **Share Extension** — Process shared text and URLs from other apps with your local models
- **App Intents** — Use Siri and Shortcuts to ask questions, rewrite, translate, and summarize text
- **Device-aware** — The app filters models by available RAM, warns when the fit is tight, and blocks models that are too large for your device
- **Thermal management** — The app monitors the device temperature and stops generation if the device becomes too hot
- **Memory safety** — The app unloads models on memory warnings and after 60 seconds in the background
- **Multi-platform** — The app runs on iOS, macOS, and visionOS with an adaptive UI (tabs on compact layouts, a sidebar on regular layouts)

## Requirements

- iOS 17.0+ / macOS 14.0+ / visionOS 1.0+
- Xcode 16.3+
- macOS 15+ (for builds)

## Getting Started

### 1. Clone the repository and initialize the submodules

```bash
git clone --recursive https://github.com/jtdub/hearth-ai-app.git
cd hearth-ai-app
```

If you cloned the repository without `--recursive`, run this command:

```bash
git submodule update --init --recursive
```

### 2. Install the dependencies

```bash
brew install xcodegen swiftlint
```

### 3. Build the llama.cpp XCFramework

This step compiles llama.cpp into a universal XCFramework for the iOS device and the simulator:

```bash
bash scripts/build-xcframework.sh
```

### 4. Generate the Xcode project

The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen). The `.xcodeproj` is generated from `project.yml`:

```bash
xcodegen generate
```

### 5. Build and run

Open `HearthAI.xcodeproj` in Xcode. Select a simulator or a device. Then run the app. You can also build from the command line:

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

1. **Download a model** — Go to the Models tab. Select a recommended model or search for one. The app shows which models are compatible with the memory of your device.
2. **Load a model** — Tap the brain icon in Chat, or go to the Library tab to load a downloaded model.
3. **Chat** — Go to the Chat tab and start a conversation. The response streams token by token.
4. **Import documents** — Go to the Documents tab to import text, PDFs, or photos (OCR). Attach a document to a conversation for Q&A.
5. **Manage memories** — Go to the Memory tab. Add personal facts, preferences, and instructions to make conversations more personal.
6. **Share Extension** — Share text or URLs from a different app to process them with your local model.
7. **Shortcuts** — Use Siri or the Shortcuts app to ask Hearth AI questions, or to rewrite, translate, or summarize text.

### Recommended Models

| Model | Size | Best for |
|-------|------|----------|
| Qwen 2.5 0.5B | ~470 MB | Tests, low-memory devices |
| Llama 3.2 1B | ~776 MB | Fast inference on mobile |
| Qwen 2.5 1.5B | ~1.1 GB | Balance of speed and quality |
| Llama 3.2 3B | ~2 GB | Strong reasoning (6GB+ RAM) |
| Phi 3.5 Mini | ~2.2 GB | High quality for its size (6GB+ RAM) |

## Architecture

The app uses **SwiftUI + MVVM** with `@Observable` view models and **SwiftData** for persistence.

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

- **Zero third-party Swift dependencies** — The only external code is the vendored llama.cpp C++ library
- **XcodeGen** — The project file is generated from `project.yml`; edit that file, not the `.xcodeproj`
- **`@MainActor` services** — All `@Observable` services and view models run on the main actor for thread safety
- **Background downloads** — The app uses `URLSessionDownloadDelegate` with an `NSLock`-protected task map for safety across isolation domains
- **Metal GPU acceleration** — llama.cpp links the Metal, MetalPerformanceShaders, and Accelerate frameworks
- **App Group shared container** — The SwiftData store is in the App Group container, so the Share Extension can read the model data
- **TF-IDF retrieval** — Document chunks and memories use TF-IDF scores to select relevant context inside token budgets

## Development

### Running Tests

The project uses the Swift Testing framework (`@Test` macro):

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

Always edit `project.yml` for build settings or target changes. Then generate the project again:

```bash
xcodegen generate
```

## CI

GitHub Actions runs on each push and each PR to `main`:

- **SwiftLint** — Strict mode with the `github-actions-logging` reporter
- **Build & Test** — Builds the XCFramework, generates the project, compiles the code, and runs all tests on an iOS Simulator

## License

This project uses the MIT License — see [LICENSE](LICENSE) for details.

Note: The vendored [llama.cpp](https://github.com/ggerganov/llama.cpp) library has its own [MIT License](Packages/LlamaCpp/vendored/llama.cpp/LICENSE).
