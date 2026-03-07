# Hearth AI

An iOS app for running large language models entirely on-device using [llama.cpp](https://github.com/ggerganov/llama.cpp). Browse and download GGUF models from Hugging Face Hub, then chat with them locally — no server, no API keys, fully private.

## Features

- **On-device inference** — Run GGUF models locally with Metal GPU acceleration
- **Model store** — Browse Hugging Face Hub, search for GGUF models, and see which ones fit your device's available memory
- **Background downloads** — Download models with pause/resume support via background URLSession
- **Conversation history** — Persistent chat history with SwiftData, multiple conversations, custom system prompts
- **Device-aware** — Automatically filters models by available RAM, warns on tight fits, blocks models too large for your device
- **Thermal management** — Monitors device temperature and pauses generation if the device overheats
- **Memory safety** — Auto-unloads models on memory warnings and after 60 seconds in the background

## Requirements

- iOS 17.0+
- Xcode 16.3+
- macOS 15+

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
xcodebuild build -project HearthAI.xcodeproj -scheme HearthAI \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO EXCLUDED_ARCHS='x86_64'
```

## Usage

1. **Download a model** — Go to the Models tab, pick a recommended model or search for one. The app shows which models are compatible with your device's memory.
2. **Load a model** — Go to the Library tab and tap a downloaded model to load it.
3. **Chat** — Switch to the Chat tab and start a conversation. Responses stream token-by-token.

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
    Settings/       App settings
  Models/         SwiftData models (LocalModel, Conversation, Message)
  Services/       Core services
    Inference/      LlamaContext wrapper, model loading, streaming generation
    Download/       Background URLSession download manager
    HuggingFace/    HF Hub REST API client
    Thermal/        Device thermal state monitoring
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

## Development

### Running Tests

Uses the Swift Testing framework (`@Test` macro):

```bash
xcodebuild test -project HearthAI.xcodeproj -scheme HearthAI \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO EXCLUDED_ARCHS='x86_64'
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
