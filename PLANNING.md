# Hearth AI — Technical Planning Document

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Project Structure](#project-structure)
3. [Technical Architecture](#technical-architecture)
4. [Open Questions Resolved](#open-questions-resolved)
5. [Phased Roadmap](#phased-roadmap)
6. [Risks & Mitigations](#risks--mitigations)

---

## Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────┐
│                    SwiftUI Layer                     │
│  ┌──────────┐  ┌──────────┐  ┌───────┐  ┌────────┐ │
│  │ Chat View│  │Model     │  │Storage│  │Settings│ │
│  │          │  │Store View│  │View   │  │View    │ │
│  └────┬─────┘  └────┬─────┘  └───┬───┘  └────┬───┘ │
│       │              │            │            │     │
│  ┌────┴─────┐  ┌────┴─────┐  ┌───┴────┐ ┌────┴───┐ │
│  │Chat      │  │ModelStore│  │Storage │ │Settings│ │
│  │ViewModel │  │ViewModel│  │VM      │ │VM      │ │
│  └────┬─────┘  └────┴─────┘  └───┬────┘ └────────┘ │
├───────┼────────────────┼──────────┼─────────────────┤
│       │         Service Layer     │                  │
│  ┌────┴──────────────────┐  ┌────┴─────────────┐    │
│  │   InferenceService    │  │  DownloadService  │    │
│  │   (LlamaContext)      │  │  (URLSession bg)  │    │
│  └────┬──────────────────┘  └────┬─────────────┘    │
│  ┌────┴──────────────────┐  ┌────┴─────────────┐    │
│  │   LlamaBridge (C++)   │  │  HuggingFaceAPI   │    │
│  └────┬──────────────────┘  └──────────────────┘    │
│  ┌────┴──────────────────┐                           │
│  │   llama.cpp (static)  │                           │
│  └───────────────────────┘                           │
├─────────────────────────────────────────────────────┤
│                  Persistence Layer                   │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────┐  │
│  │ SwiftData   │  │ File Manager │  │UserDefaults│  │
│  │ (models,    │  │ (GGUF files) │  │ (prefs)    │  │
│  │  convos)    │  │              │  │            │  │
│  └─────────────┘  └──────────────┘  └────────────┘  │
└─────────────────────────────────────────────────────┘
```

### Key Architectural Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| UI Framework | SwiftUI + MVVM | Native, declarative, fits iOS 17+ target |
| Persistence | SwiftData | Apple-native, simpler than Core Data, iOS 17+ |
| llama.cpp integration | Swift Package (local) | Best Xcode integration, easier updates, no manual XCFramework builds |
| Networking | URLSession (background) | Native background download support, no third-party dependency |
| Model format | GGUF only | llama.cpp native format; one format makes the design simpler |
| Navigation | TabView (3 tabs) | Chat, Model Store, Settings — clear separation |

---

## Project Structure

```
HearthAI/
├── HearthAI.xcodeproj
├── Packages/
│   └── LlamaCpp/                          # Local Swift Package wrapping llama.cpp
│       ├── Package.swift
│       ├── Sources/
│       │   ├── CLlama/                    # C/C++ bridge target
│       │   │   ├── include/
│       │   │   │   └── llama_bridge.h     # Public C header exposed to Swift
│       │   │   ├── llama_bridge.cpp        # C++ implementation calling llama.cpp
│       │   │   └── module.modulemap
│       │   └── LlamaCpp/                  # Swift target
│       │       └── LlamaContext.swift     # Swift wrapper around C bridge
│       └── vendored/
│           └── llama.cpp/                 # Git submodule of llama.cpp source
│               ├── ggml/
│               ├── src/
│               ├── include/
│               └── ...
├── HearthAI/
│   ├── App/
│   │   ├── HearthAIApp.swift              # @main entry point
│   │   ├── AppState.swift                 # Global app state / DI container
│   │   └── ContentView.swift              # Root TabView
│   │
│   ├── Models/                            # SwiftData models
│   │   ├── LocalModel.swift               # Downloaded model metadata
│   │   ├── Conversation.swift             # Chat conversation
│   │   ├── Message.swift                  # Individual chat message
│   │   └── FeaturedModel.swift            # Curated model definitions
│   │
│   ├── Services/
│   │   ├── Inference/
│   │   │   ├── InferenceService.swift     # High-level inference API
│   │   │   └── InferenceConfiguration.swift # Temperature, top-p, etc.
│   │   ├── Download/
│   │   │   ├── DownloadService.swift      # Background download manager
│   │   │   ├── DownloadTask.swift         # Individual download state
│   │   │   └── StorageManager.swift       # Disk space queries, model file ops
│   │   ├── HuggingFace/
│   │   │   ├── HuggingFaceAPI.swift       # HF Hub REST client
│   │   │   ├── HFModelInfo.swift          # API response models
│   │   │   └── HFEndpoints.swift          # Endpoint URL construction
│   │   └── Thermal/
│   │       └── ThermalMonitor.swift       # ProcessInfo thermal state observer
│   │
│   ├── Features/
│   │   ├── Chat/
│   │   │   ├── ChatView.swift             # Main chat interface
│   │   │   ├── ChatViewModel.swift        # Chat logic, drives inference
│   │   │   ├── MessageBubble.swift        # Individual message view
│   │   │   ├── ModelPickerView.swift      # In-chat model selector
│   │   │   └── ChatSettingsSheet.swift    # Per-conversation settings
│   │   ├── ModelStore/
│   │   │   ├── ModelStoreView.swift       # Browse/search models
│   │   │   ├── ModelStoreViewModel.swift  # HF API integration
│   │   │   ├── ModelDetailView.swift      # Model info + download button
│   │   │   ├── ModelCardView.swift        # Grid/list item
│   │   │   └── FeaturedModelsSection.swift
│   │   ├── Library/
│   │   │   ├── LibraryView.swift          # Downloaded models management
│   │   │   ├── LibraryViewModel.swift
│   │   │   └── StorageDashboard.swift     # Storage usage visualization
│   │   └── Settings/
│   │       ├── SettingsView.swift
│   │       └── SettingsViewModel.swift
│   │
│   ├── Shared/
│   │   ├── Extensions/
│   │   │   ├── FileManager+AppSupport.swift
│   │   │   ├── ByteCountFormatter+.swift
│   │   │   └── ProcessInfo+Thermal.swift
│   │   ├── Components/
│   │   │   ├── ProgressBar.swift
│   │   │   └── WarningBanner.swift
│   │   └── Constants.swift                # App-wide constants
│   │
│   ├── Resources/
│   │   ├── Assets.xcassets
│   │   ├── FeaturedModels.json            # Bundled curated model list
│   │   └── Localizable.strings
│   │
│   └── Preview Content/
│       └── PreviewData.swift
│
├── HearthAITests/
│   ├── InferenceServiceTests.swift
│   ├── DownloadServiceTests.swift
│   └── HuggingFaceAPITests.swift
│
└── PLANNING.md                            # This file
```

### Swift Package Dependencies

| Package | Purpose | Source |
|---------|---------|-------|
| LlamaCpp (local) | llama.cpp inference | Local package in `Packages/` |

**No external SPM dependencies.** The goal is zero third-party dependencies except llama.cpp itself. URLSession does the networking. SwiftData does the persistence. SwiftUI does the UI.

---

## Technical Architecture

### 1. llama.cpp Integration — Local Swift Package

**Why a local Swift Package and not an XCFramework:**
- Xcode builds it as part of the project — no separate build step
- To update llama.cpp, update the git submodule
- Supports incremental builds
- The C++ interop is simpler with modulemaps in SPM
- An XCFramework needs a pre-build for each architecture, which makes CI more complex

**Package.swift:**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LlamaCpp",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "LlamaCpp", targets: ["LlamaCpp"])
    ],
    targets: [
        // C/C++ target that compiles llama.cpp and the bridge
        .target(
            name: "CLlama",
            path: "Sources/CLlama",
            sources: [
                "llama_bridge.cpp",
                "../../vendored/llama.cpp/src/llama.cpp",
                "../../vendored/llama.cpp/src/llama-vocab.cpp",
                "../../vendored/llama.cpp/src/llama-sampling.cpp",
                "../../vendored/llama.cpp/src/llama-grammar.cpp",
                "../../vendored/llama.cpp/ggml/src/ggml.c",
                "../../vendored/llama.cpp/ggml/src/ggml-alloc.c",
                "../../vendored/llama.cpp/ggml/src/ggml-backend.c",
                "../../vendored/llama.cpp/ggml/src/ggml-metal.m",
                "../../vendored/llama.cpp/ggml/src/ggml-quants.c",
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("../../vendored/llama.cpp/include"),
                .headerSearchPath("../../vendored/llama.cpp/ggml/include"),
                .define("GGML_USE_METAL"),
                .define("ACCELERATE_NEW_LAPACK"),
            ],
            cxxSettings: [
                .headerSearchPath("../../vendored/llama.cpp/include"),
                .headerSearchPath("../../vendored/llama.cpp/ggml/include"),
                .headerSearchPath("../../vendored/llama.cpp/src"),
                .define("GGML_USE_METAL"),
            ],
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("Accelerate"),
                .linkedFramework("Foundation"),
            ]
        ),
        // Swift target that wraps CLlama
        .target(
            name: "LlamaCpp",
            dependencies: ["CLlama"],
            path: "Sources/LlamaCpp"
        )
    ],
    cxxLanguageStandard: .cxx17
)
```

> **Caution:** The llama.cpp source file list changes between releases. When you update, examine which `.c`/`.cpp` files are necessary. See the llama.cpp CMakeLists.txt for the current file list. The list above is an example — the applicable source files depend on the llama.cpp version that you vendor.

**C Bridge Header (`llama_bridge.h`):**

```c
#ifndef LLAMA_BRIDGE_H
#define LLAMA_BRIDGE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque context handle
typedef struct llama_bridge_context llama_bridge_context;

// Callback for streaming tokens
typedef void (*llama_bridge_token_callback)(const char* token, void* user_data);

// Lifecycle
llama_bridge_context* llama_bridge_create(const char* model_path,
                                           int32_t n_ctx,
                                           int32_t n_gpu_layers,
                                           bool use_mmap);
void llama_bridge_destroy(llama_bridge_context* ctx);

// Inference
int32_t llama_bridge_generate(llama_bridge_context* ctx,
                               const char* prompt,
                               int32_t max_tokens,
                               float temperature,
                               float top_p,
                               float repeat_penalty,
                               llama_bridge_token_callback callback,
                               void* user_data,
                               volatile bool* cancel_flag);

// Info
int32_t llama_bridge_context_size(llama_bridge_context* ctx);
int64_t llama_bridge_model_size(llama_bridge_context* ctx);

#ifdef __cplusplus
}
#endif

#endif
```

**Swift Wrapper (`LlamaContext.swift`):**

```swift
import CLlama
import Foundation

public actor LlamaContext {
    private var context: OpaquePointer?
    private var cancelFlag: UnsafeMutablePointer<Bool>

    public init(modelPath: String, contextSize: Int32 = 2048, gpuLayers: Int32 = 99) throws {
        cancelFlag = .allocate(capacity: 1)
        cancelFlag.pointee = false

        guard let ctx = llama_bridge_create(modelPath, contextSize, gpuLayers, true) else {
            cancelFlag.deallocate()
            throw LlamaError.failedToLoadModel
        }
        self.context = ctx
    }

    deinit {
        if let context {
            llama_bridge_destroy(context)
        }
        cancelFlag.deallocate()
    }

    public func generate(
        prompt: String,
        maxTokens: Int32 = 512,
        temperature: Float = 0.7,
        topP: Float = 0.9,
        repeatPenalty: Float = 1.1
    ) -> AsyncStream<String> {
        cancelFlag.pointee = false

        return AsyncStream { continuation in
            let callbackUserData = Unmanaged.passRetained(
                TokenCallbackContext(continuation: continuation)
            ).toOpaque()

            // Run inference on a background queue
            Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }

                let ctx = await self.context
                let flag = await self.cancelFlag

                llama_bridge_generate(
                    ctx,
                    prompt,
                    maxTokens,
                    temperature,
                    topP,
                    repeatPenalty,
                    { tokenCStr, userData in
                        guard let userData, let tokenCStr else { return }
                        let context = Unmanaged<TokenCallbackContext>
                            .fromOpaque(userData)
                            .takeUnretainedValue()
                        let token = String(cString: tokenCStr)
                        context.continuation.yield(token)
                    },
                    callbackUserData,
                    flag
                )

                // Clean up
                Unmanaged<TokenCallbackContext>.fromOpaque(callbackUserData).release()
                continuation.finish()
            }
        }
    }

    public func cancel() {
        cancelFlag.pointee = true
    }
}

private final class TokenCallbackContext: @unchecked Sendable {
    let continuation: AsyncStream<String>.Continuation
    init(continuation: AsyncStream<String>.Continuation) {
        self.continuation = continuation
    }
}

public enum LlamaError: Error, LocalizedError {
    case failedToLoadModel
    case inferenceError(String)

    public var errorDescription: String? {
        switch self {
        case .failedToLoadModel: "Failed to load the model file."
        case .inferenceError(let msg): "Inference error: \(msg)"
        }
    }
}
```

### 2. Data Layer

**SwiftData Models:**

```swift
// LocalModel.swift
import SwiftData
import Foundation

@Model
final class LocalModel {
    @Attribute(.unique) var id: String          // HF repo ID + filename
    var repoId: String                          // e.g. "TheBloke/Llama-2-7B-Chat-GGUF"
    var fileName: String                        // e.g. "llama-2-7b-chat.Q4_K_M.gguf"
    var displayName: String
    var modelFamily: String                     // "Llama", "Phi", "Mistral", etc.
    var quantization: String                    // "Q4_K_M", "Q5_K_M", etc.
    var fileSizeBytes: Int64
    var downloadedAt: Date
    var lastUsedAt: Date?
    var localPath: String                       // Relative to App Support dir

    // Computed
    var absolutePath: URL {
        FileManager.appSupportDirectory
            .appendingPathComponent("Models")
            .appendingPathComponent(localPath)
    }
}

// Conversation.swift
@Model
final class Conversation {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var systemPrompt: String
    var temperature: Float
    var topP: Float
    var contextLength: Int32
    var modelId: String?                        // Links to LocalModel.id

    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message] = []
}

// Message.swift
@Model
final class Message {
    @Attribute(.unique) var id: UUID
    var role: String                            // "user", "assistant", "system"
    var content: String
    var createdAt: Date
    var tokenCount: Int32?

    var conversation: Conversation?
}
```

**Why SwiftData and not the alternatives:**
- **vs Core Data:** SwiftData is the modern replacement. It has a simpler API, uses macros, and integrates better with SwiftUI. The iOS 17+ target makes this possible.
- **vs flat JSON:** Flat JSON has no queries, no migration support, and manual serialization. It is satisfactory for a manifest, but not for a conversation history that can become large.
- **vs SQLite (direct):** SwiftData gives the same query functions without raw SQL code.

**Settings — UserDefaults (via AppStorage):**

Settings are simple key-value pairs. They do not need a heavier persistence layer:

```swift
// Used directly in SwiftUI views via @AppStorage
@AppStorage("defaultModelId") var defaultModelId: String = ""
@AppStorage("appTheme") var appTheme: String = "system"  // "light", "dark", "system"
@AppStorage("thermalThrottling") var thermalThrottling: Bool = true
```

### 3. Networking Layer

**Hugging Face Hub API Endpoints:**

```
# Search for GGUF models
GET https://huggingface.co/api/models?search=gguf&filter=gguf&sort=downloads&direction=-1&limit=20

# Get model info (file listing)
GET https://huggingface.co/api/models/{repo_id}

# List files in a repo (to find GGUF files)
GET https://huggingface.co/api/models/{repo_id}/tree/main

# Download a file (direct)
GET https://huggingface.co/resolve/{repo_id}/main/{filename}
```

**Authentication:** The HF API is open for public repos without authentication. You do not need an API key to browse and download public GGUF models. The rate limits for unauthenticated requests are enough for the usage of an app. If rate limits become a problem, users can supply an optional HF token in settings.

**HuggingFaceAPI.swift (key patterns):**

```swift
final class HuggingFaceAPI {
    private let session = URLSession.shared
    private let baseURL = URL(string: "https://huggingface.co/api")!

    func searchModels(query: String, limit: Int = 20) async throws -> [HFModelInfo] {
        var components = URLComponents(url: baseURL.appendingPathComponent("models"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "filter", value: "gguf"),
            URLQueryItem(name: "sort", value: "downloads"),
            URLQueryItem(name: "direction", value: "-1"),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        let (data, _) = try await session.data(from: components.url!)
        return try JSONDecoder().decode([HFModelInfo].self, from: data)
    }

    func listFiles(repoId: String) async throws -> [HFFileInfo] {
        let url = baseURL
            .appendingPathComponent("models")
            .appendingPathComponent(repoId)
            .appendingPathComponent("tree/main")
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([HFFileInfo].self, from: data)
    }

    func downloadURL(repoId: String, fileName: String) -> URL {
        URL(string: "https://huggingface.co/\(repoId)/resolve/main/\(fileName)")!
    }
}
```

**Background Download Architecture:**

```swift
final class DownloadService: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = DownloadService()

    @Published var activeDownloads: [String: DownloadTask] = [:]

    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "ai.hearth.download")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private var completionHandlers: [String: (URL) -> Void] = [:]

    func download(url: URL, modelId: String) {
        let task = backgroundSession.downloadTask(with: url)
        task.taskDescription = modelId
        task.resume()

        DispatchQueue.main.async {
            self.activeDownloads[modelId] = DownloadTask(
                modelId: modelId,
                urlSessionTask: task,
                progress: 0,
                state: .downloading
            )
        }
    }

    func pause(modelId: String) {
        guard let download = activeDownloads[modelId] else { return }
        download.urlSessionTask.cancel(byProducingResumeData: { data in
            DispatchQueue.main.async {
                self.activeDownloads[modelId]?.resumeData = data
                self.activeDownloads[modelId]?.state = .paused
            }
        })
    }

    func resume(modelId: String) {
        guard let download = activeDownloads[modelId],
              let resumeData = download.resumeData else { return }
        let task = backgroundSession.downloadTask(withResumeData: resumeData)
        task.taskDescription = modelId
        task.resume()
        DispatchQueue.main.async {
            self.activeDownloads[modelId]?.urlSessionTask = task
            self.activeDownloads[modelId]?.state = .downloading
            self.activeDownloads[modelId]?.resumeData = nil
        }
    }

    // URLSessionDownloadDelegate
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        guard let modelId = downloadTask.taskDescription else { return }
        // Move file from temp to Application Support/Models/
        let dest = FileManager.appSupportDirectory
            .appendingPathComponent("Models")
            .appendingPathComponent(modelId)
        try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(),
                                                  withIntermediateDirectories: true)
        try? FileManager.default.moveItem(at: location, to: dest)

        DispatchQueue.main.async {
            self.activeDownloads[modelId]?.state = .completed
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard let modelId = downloadTask.taskDescription else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.activeDownloads[modelId]?.progress = progress
        }
    }
}
```

**Download queue strategy:** Download files one at a time (serial queue). GGUF files are 2-8 GB. Concurrent downloads would use all the bandwidth, and iOS could stop the app for too much resource use. Put more downloads in a queue. Start the next download when one download completes.

### 4. Inference Layer

**Threading Model:**

```
Main Thread (SwiftUI)
    │
    ├── ChatViewModel (ObservableObject)
    │       │
    │       └── calls InferenceService.generate()
    │               │
    │               └── LlamaContext.generate() [Swift actor]
    │                       │
    │                       └── Task.detached(priority: .userInitiated)
    │                               │
    │                               └── llama_bridge_generate() [C++, runs on background thread]
    │                                       │
    │                                       └── token callback → AsyncStream yield
    │                                               │
    │                                               └── for await token in stream (ChatViewModel)
    │                                                       │
    │                                                       └── @MainActor update UI
```

- **LlamaContext is a Swift `actor`** — it serializes access and prevents concurrent inference calls
- **Inference runs in `Task.detached`** — it does not block the actor or the main thread
- **Tokens stream through `AsyncStream`** — this gives backpressure control and easy cancellation
- **Cancel flag** — a volatile bool pointer, shared with C++, stops generation immediately

**Model Loading/Unloading:**

```swift
final class InferenceService: ObservableObject {
    @Published var loadedModelId: String?
    @Published var isLoading = false

    private var context: LlamaContext?

    func loadModel(_ model: LocalModel) async throws {
        // Unload current model first
        await unloadModel()

        isLoading = true
        defer { isLoading = false }

        context = try LlamaContext(
            modelPath: model.absolutePath.path,
            contextSize: 2048,
            gpuLayers: 99  // Offload everything to Metal
        )
        loadedModelId = model.id
    }

    func unloadModel() async {
        context = nil  // Actor deinit handles cleanup
        loadedModelId = nil
    }

    func generate(prompt: String, config: InferenceConfiguration) -> AsyncStream<String>? {
        context?.generate(
            prompt: prompt,
            maxTokens: config.maxTokens,
            temperature: config.temperature,
            topP: config.topP,
            repeatPenalty: config.repeatPenalty
        )
    }
}
```

**Keep the model loaded in memory:** The model stays loaded in the `InferenceService.context` property between conversations. To manage memory pressure:

```swift
// In AppState or InferenceService init
NotificationCenter.default.addObserver(
    forName: UIApplication.didReceiveMemoryWarningNotification,
    object: nil, queue: .main
) { [weak self] _ in
    Task { await self?.inferenceService.unloadModel() }
}
```

Strategy: Keep the model loaded. Unload it when the user changes models. Unload it when a memory warning occurs. Unload it when the app stays in the background for more than 60 seconds. After a relaunch or a return from the background, load the model again when the user sends a message.

**Context Management / Conversation Windowing:**

```swift
func buildPrompt(messages: [Message], systemPrompt: String, maxContext: Int32) -> String {
    // Use chat template format (Llama-style shown here)
    var prompt = "<s>[INST] <<SYS>>\n\(systemPrompt)\n<</SYS>>\n\n"

    // Walk messages from newest to oldest, accumulating until we approach
    // the context limit (estimate ~4 chars per token as a rough heuristic)
    let charBudget = Int(maxContext) * 4
    var charCount = prompt.count
    var includedMessages: [Message] = []

    for message in messages.reversed() {
        let msgLen = message.content.count + 20 // overhead for role tags
        if charCount + msgLen > charBudget { break }
        includedMessages.insert(message, at: 0)
        charCount += msgLen
    }

    for message in includedMessages {
        if message.role == "user" {
            prompt += "\(message.content) [/INST] "
        } else {
            prompt += "\(message.content) </s><s>[INST] "
        }
    }

    return prompt
}
```

> **Note:** Different model families use different chat templates. Make the prompt builder template-aware. Store the template type as metadata on the model (Llama, ChatML, Phi, etc.). Change the format to agree with the template type.

### 5. SwiftUI Architecture

**Navigation — TabView with 3 tabs:**

```swift
struct ContentView: View {
    var body: some View {
        TabView {
            ChatView()
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }

            ModelStoreView()
                .tabItem { Label("Models", systemImage: "square.grid.2x2") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}
```

**Streaming Output Pattern:**

```swift
@Observable
final class ChatViewModel {
    var messages: [Message] = []
    var isGenerating = false
    var streamingText = ""

    private let inferenceService: InferenceService

    func send(_ text: String) async {
        // Add user message
        let userMsg = Message(role: "user", content: text)
        messages.append(userMsg)

        // Build prompt
        let prompt = buildPrompt(messages: messages, ...)

        // Start streaming
        isGenerating = true
        streamingText = ""

        guard let stream = inferenceService.generate(prompt: prompt, config: config) else {
            return
        }

        for await token in stream {
            streamingText += token
        }

        // Finalize
        let assistantMsg = Message(role: "assistant", content: streamingText)
        messages.append(assistantMsg)
        streamingText = ""
        isGenerating = false

        // Persist conversation
        saveConversation()
    }
}
```

**Chat View — show the streamed text:**

```swift
struct ChatView: View {
    @State private var viewModel = ChatViewModel()
    @State private var inputText = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                        }
                        // Show streaming text as it arrives
                        if viewModel.isGenerating {
                            MessageBubble(
                                message: Message(role: "assistant",
                                                content: viewModel.streamingText)
                            )
                            .id("streaming")
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.streamingText) {
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }

            // Input bar
            HStack {
                TextField("Message", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)

                Button {
                    let text = inputText
                    inputText = ""
                    Task { await viewModel.send(text) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(inputText.isEmpty || viewModel.isGenerating)
            }
            .padding()
        }
    }
}
```

### 6. Thermal Monitoring

```swift
final class ThermalMonitor: ObservableObject {
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var shouldWarnUser = false

    init() {
        thermalState = ProcessInfo.processInfo.thermalState

        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            let state = ProcessInfo.processInfo.thermalState
            self?.thermalState = state
            self?.shouldWarnUser = (state == .serious || state == .critical)
        }
    }
}
```

---

## Open Questions Resolved

### 1. Swift Package vs. XCFramework for llama.cpp?

**Recommendation: Local Swift Package (as detailed above).**

| | Swift Package | XCFramework |
|---|---|---|
| Build integration | Automatic, Xcode builds it | Manual pre-build step |
| Updating llama.cpp | Update submodule, rebuild | Rebuild framework, re-import |
| Debug symbols | Full, step into C++ code | Needs dSYM management |
| CI complexity | Low — just `xcodebuild` | High — separate build script per arch |
| Initial setup | More work to get Package.swift right | Simpler if you have a working build |

**Tradeoff:** The Package.swift for llama.cpp is difficult to configure correctly (source file lists, header search paths, Metal framework links). But after it operates, it is much easier to maintain. See the approach of LLM Farm — they use a similar local package pattern.

### 2. Keep a model loaded in memory?

**Strategy: Hold the `LlamaContext` in `InferenceService`. Release it on a memory warning.**

- Keep the model loaded between conversations. A 4GB model takes 2-5 seconds to load. Users will see the delay if they must wait each time.
- Register for `didReceiveMemoryWarningNotification` and unload the model immediately.
- When the app goes to the background, start a 60-second timer. If the app does not return to the foreground in that time, unload the model. This prevents iOS from stopping the app for too much background memory use.
- For reference: a Q4_K_M 7B model uses about 4GB RAM. The iPhone 15 Pro has 8GB total, and about 5-6GB is available to apps. This gives spare memory, but a Q4_K_M 13B model (about 7.5GB) leaves almost no spare memory. The device gating feature (Phase 3) must prevent downloads of models that do not fit.

### 3. App Store considerations for large post-install downloads?

Obey these guidelines:

- **Guideline 2.5.4:** Apple can reject apps that download executable code. GGUF model files are **data files, not executable code** — they are weight matrices. This is the same as a download of images or audio. But make sure that all review notes show the models as data.
- **Guideline 4.2.3:** The app must operate at launch (without downloads). Include a clear onboarding flow that shows users how to download their first model. One option is a small bundled model (about 100MB) for immediate first use. A second option is to show clearly that the app needs a download to operate, the same as a podcast app needs episodes.
- **Review note to submit:** "Hearth AI is a local AI chat application. Model files are neural network weight data (GGUF format) downloaded from Hugging Face Hub. These are not executable code. All inference runs on-device using the open-source llama.cpp library. No user data leaves the device."
- **Storage:** Use the `Application Support` directory (not Documents or Caches). Set `isExcludedFromBackup = true` on the files to prevent iCloud backups of many GB.
- **NSAppTransportSecurity:** huggingface.co uses HTTPS — no ATS exceptions are necessary.

### 4. Quantization recommendations by device?

| Device | RAM | Recommended Quants | Max Model Size |
|--------|-----|-------------------|----------------|
| iPhone 13 Pro / 14 Pro | 6 GB | Q4_K_M (1-3B), Q4_K_S (7B) | about 3.5 GB file |
| iPhone 15 Pro / 16 Pro | 8 GB | Q4_K_M (7B), Q5_K_M (3B) | about 5 GB file |
| iPhone 16 Pro Max | 8 GB | Q4_K_M (7B), Q5_K_M (7B) | about 5.5 GB file |
| iPad Pro M-series | 8-16 GB | Q5_K_M (7B), Q8_0 (7B), Q4_K_M (13B) | about 8 GB file |

**General rule for device gating:** Model file size + 2GB overhead < total device RAM. Query the available RAM with `os_proc_available_memory()` at runtime.

**Recommended defaults for the "Featured Models" section:**
- **Starter:** Phi-3-mini-4k (3.8B, Q4_K_M, about 2.2GB) — operates on all supported devices
- **Standard:** Llama-3.2-3B-Instruct (Q4_K_M, about 1.8GB) — very good quality/size ratio
- **Advanced:** Mistral-7B-Instruct (Q4_K_M, about 4.1GB) — 8GB+ devices only
- **Power:** Qwen2.5-7B-Instruct (Q4_K_M, about 4.4GB) — 8GB+ devices only

### 5. Conversation history — per-model or global?

**Recommendation: Global conversations, each tagged with the model used.**

- SwiftData stores all conversations globally with a `modelId` field.
- Users can see all conversations or filter them by model.
- If the user deletes a model, its conversations stay visible as read-only history. The user cannot continue them until a model is loaded again.
- **Retention strategy:** Keep all conversations without a time limit. They are only text and use very little space. Supply a "Delete All Conversations" option in settings. Supply swipe-to-delete on each conversation.

---

## Phased Roadmap

### Phase 1: Core Inference (Weeks 1-3)

**Goal:** Run llama.cpp on the device, with one bundled test model and a basic chat UI that streams tokens.

**Tasks:**

1. **Xcode project setup**
   - Create a new iOS 17+ SwiftUI project
   - Set up the folder structure as the plan above shows
   - Add `.gitignore` for Xcode, Swift, and GGUF files

2. **llama.cpp local package**
   - Create `Packages/LlamaCpp/` directory structure
   - Add llama.cpp as a git submodule in `vendored/`
   - Write `Package.swift` with correct source files and Metal linking
   - Write `llama_bridge.h` and `llama_bridge.cpp`
   - Write `LlamaContext.swift` with `AsyncStream` token streaming
   - Test: build the package standalone, and make sure that Metal acceleration operates

3. **InferenceService**
   - Implement `InferenceService` with `loadModel()`, `unloadModel()`, `generate()`
   - Implement a memory warning observer for automatic unload
   - Test: load a model, generate text, and make sure that the tokens stream

4. **Basic Chat UI**
   - `ChatView` with message list and input bar
   - `MessageBubble` component (user vs assistant styling)
   - `ChatViewModel` that bridges `InferenceService` to UI
   - Show the streamed text with auto-scroll
   - Stop generation button

5. **Bundle a test model**
   - Download a small GGUF (about 100MB, e.g., TinyLlama-1.1B Q4_K_M) into the project for tests
   - Add it to the app bundle for Phase 1 tests only (remove it before Phase 2)

**Problems to avoid:**
- The llama.cpp Metal shaders must be in the bundle. Make sure that `ggml-metal.metal` is included in the build. It is possible that you must add it as a resource in the SPM target, or copy it in a build phase.
- The first build is slow because it compiles llama.cpp. Later builds are incremental.
- The Simulator does not support Metal GPU inference. Test on a **real device** early.

**Deliverable:** The app starts and loads a bundled model. The user can type a message and see a streamed AI response.

---

### Phase 2: Model Store & Downloads (Weeks 4-6)

**Goal:** Users can browse the HF Hub, download GGUF models, and manage local storage.

**Tasks:**

1. **HuggingFaceAPI service**
   - Implement `searchModels()`, `listFiles()`, `downloadURL()`
   - Parse HF API responses into `HFModelInfo` and `HFFileInfo` structs
   - Handle pagination and error states

2. **Download service**
   - Implement `DownloadService` with background URLSession
   - Pause/resume/cancel support
   - File move from temp to `Application Support/Models/`
   - Download queue (serial)
   - Reconnect to active downloads when the app starts again (make the URLSession background session again)

3. **SwiftData persistence**
   - Define `LocalModel` SwiftData schema
   - Save the model metadata when a download completes
   - Delete model files and records

4. **Model Store UI**
   - `ModelStoreView` with a search bar and a results grid
   - `ModelCardView` that shows name, size, quant, and download count
   - `ModelDetailView` with full metadata and a download button
   - `FeaturedModelsSection` with a curated selection (loaded from bundled JSON)
   - Download progress UI (progress bar, pause/cancel buttons)

5. **Library / Storage UI**
   - `LibraryView` that lists the downloaded models
   - Delete a model (swipe or button)
   - `StorageDashboard` that shows per-model and total storage usage
   - Show the available device storage

6. **TabView navigation**
   - Change from a single view to a TabView (Chat, Models, Settings)
   - Model selector in the Chat view (select from the downloaded models)

**Problems to avoid:**
- Background URLSession delegates run even when the app is suspended. Implement `application(_:handleEventsForBackgroundURLSession:completionHandler:)` in the App Delegate (or use the SwiftUI equivalent `.backgroundTask`) to handle completion.
- The HF API returns all files in a repo. Filter the list to show only `.gguf` files.
- Some HF repos have many quantization variants. Group them by quantization level in the UI.
- Test the download behavior when the app stops during a download. The background URLSession must continue the download.

**Deliverable:** Users can browse the HF Hub, download models, see them in their library, select a model, and chat with it.

---

### Phase 3: Polish & Hardening (Weeks 7-9)

**Goal:** Add device gating, thermal awareness, conversation history, settings, and a production UX.

**Tasks:**

1. **Device compatibility gating**
   - Query `os_proc_available_memory()` at runtime
   - Compare the result with the model file size + 2GB overhead
   - Show a warning on `ModelDetailView` if the model possibly does not fit
   - Disable the download button for models that cannot operate

2. **Thermal monitoring**
   - Implement `ThermalMonitor`
   - Show a warning banner in Chat when the thermal state is `.serious`
   - Automatically pause generation at `.critical` (or decrease the token speed)
   - Show the suggestion: "Your device is warm. Consider a smaller model."

3. **Conversation history**
   - Define `Conversation` and `Message` SwiftData models
   - Save conversations automatically after each assistant response
   - Conversation list sidebar/drawer in Chat
   - New conversation, delete conversation, rename conversation
   - Conversation continuity — load the previous messages when the user opens the conversation again

4. **Chat enhancements**
   - Copy a message to the clipboard (long press or button)
   - Generate the last response again
   - Clear conversation
   - Per-conversation settings sheet (system prompt, temperature, top-p, context length)
   - Chat template awareness (Llama, ChatML, Phi, Gemma formats)

5. **Settings screen**
   - Default model picker
   - Theme selection (light/dark/system)
   - Storage info
   - Thermal throttling toggle
   - About / licenses (llama.cpp MIT, HF attribution)

6. **Error handling & edge cases**
   - Find model file corruption (basic: make sure that the file size is equal to the expected size)
   - Network error handling in the Model Store (retry, offline state)
   - Handle a model load failure without a crash
   - App lifecycle: save the state when the app goes to the background, restore it in the foreground

**Problems to avoid:**
- `os_proc_available_memory()` returns the available memory *at that moment*, and this value changes. Use it as a guide, not a hard limit.
- If the chat template is not correct, the models will make unreadable output. Different model families need different chat templates. Make a registry that maps each model family to a template formatter.
- Thermal state `.critical` means that iOS can stop the app. This is an important risk.

**Deliverable:** A full-featured app with conversation history, device awareness, settings, and a polished UX.

---

### Phase 4: App Store Prep (Weeks 10-11)

**Goal:** Complete TestFlight, App Store submission, metadata, and review preparation.

**Tasks:**

1. **App Store metadata**
   - App name: "Hearth AI"
   - Subtitle: "Private AI Chat, On-Device"
   - Description that shows the privacy points: no cloud, no data collection
   - Keywords: AI, chat, private, offline, local, LLM
   - Screenshots (iPhone 15 Pro and iPhone 16 Pro Max sizes at minimum)
   - App icon (warm, hearth/fireplace aesthetic)

2. **Privacy & compliance**
   - Privacy Nutrition Label: "Data Not Collected" (no analytics, no tracking)
   - No App Tracking Transparency prompt is necessary (no tracking)
   - Privacy Policy URL (a simple page is enough: "Hearth AI collects no data")
   - Export compliance: llama.cpp uses standard algorithms and probably qualifies for the encryption exemption (ERN). File the self-classification in App Store Connect.

3. **TestFlight**
   - Internal testing group
   - Test on: iPhone 13 Pro, iPhone 15 Pro, iPhone 16 Pro (different RAM tiers)
   - Test scenarios:
     - Fresh install → download model → chat
     - Background download → app stopped → relaunch (the download must continue)
     - Memory pressure during inference
     - Thermal throttling during long generation
     - Storage full scenario
     - Airplane mode with downloaded models (the app must operate fully)

4. **Review preparation**
   - Review notes that show that GGUF files are data, not code
   - No demo account is necessary (no accounts in the app)
   - Make sure that the app operates at the first launch (also without models — show onboarding)
   - Make sure that the app uses no private API

5. **Performance optimization**
   - Profile with Instruments: Metal System Trace, Time Profiler
   - Make sure that the app uses Metal GPU inference (not the CPU fallback)
   - Optimize the ScrollView performance for long conversations (LazyVStack)
   - Test with large models (7B) for memory stability

**Problems to avoid:**
- The first submission of an app of this type can get more examination. Be prepared for questions from the reviewer.
- Apple can flag the app for review if it downloads files of more than 200MB on a cellular connection. Add a WiFi-only download option or a warning.
- The app binary itself must be small (less than 50MB). The downloaded models contain almost all the data.

**Deliverable:** The app is on TestFlight, then submitted to the App Store.

---

## Risks & Mitigations

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|-----------|--------|------------|
| 1 | **llama.cpp SPM build breaks on update** | High | Medium | Pin to a specific llama.cpp commit. Update with care. Keep a reference build that operates. |
| 2 | **App rejected for "downloading executable code"** | Medium | High | Prepare clear review notes. GGUF files are weight data, not code. Refer to precedent (other GGUF apps are on the App Store). |
| 3 | **OOM crash on large models** | High | High | Use device gating and `os_proc_available_memory()` checks before load. Use a memory warning observer to unload. Use conservative RAM estimates. |
| 4 | **Metal shader missing from bundle** | Medium | High | Make sure that `ggml-metal.metal` is included in the build. Test on a device (not the simulator). Add a build-phase copy if SPM does not include the file. |
| 5 | **Background download reliability** | Medium | Medium | Use a correct background URLSession. Handle `handleEventsForBackgroundURLSession`. Test the scenario where the app stops during a download. |
| 6 | **HF API rate limiting** | Low | Medium | Cache the search results. Add optional HF token support. Implement exponential backoff. |
| 7 | **Thermal throttling degrades UX** | Medium | Medium | Monitor the thermal state. Warn users. Suggest smaller models. Automatically decrease the generation speed at `.serious`. |
| 8 | **Chat template mismatches** | High | Medium | Make the template registry at the start. Test each featured model with its correct template. Use ChatML as the default if the template is unknown. |
| 9 | **Model file corruption** | Low | Low | Make sure that the file size is correct after download. Validate the checksum if HF supplies a SHA256 (the API supplies it). Give a re-download option. |
| 10 | **llama.cpp source files change between versions** | High | Medium | Examine the llama.cpp CMakeLists.txt when you update. A script can make the SPM source file list from CMakeLists.txt. |

---

## Summary

The architecture of Hearth AI is simple: a SwiftUI MVVM app with a local Swift Package around llama.cpp, SwiftData for persistence, and a background URLSession for downloads. The complexity is in three areas:

1. **Build and run llama.cpp correctly in SPM** — difficult but possible, and the reference projects (LLM Farm) show that it operates.
2. **Memory management** — the app must keep models loaded and also obey the iOS memory limits. This needs careful lifecycle management.
3. **Chat template correctness** — different model families need different prompt formats. An incorrect format makes bad output.

The four-phase plan gives a chat app that operates in about 3 weeks, a full-featured app in about 9 weeks, and an App Store submission in about 11 weeks. Each phase has a concrete deliverable that you can test independently.
