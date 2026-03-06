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
| Networking | URLSession (background) | Native background download support, no 3rd-party dependency |
| Model format | GGUF only | llama.cpp native format, single format simplifies everything |
| Navigation | TabView (3 tabs) | Chat, Model Store, Settings — clean separation |

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

**No external SPM dependencies.** The goal is zero third-party dependencies beyond llama.cpp itself. URLSession handles networking. SwiftData handles persistence. SwiftUI handles UI.

---

## Technical Architecture

### 1. llama.cpp Integration — Local Swift Package

**Why a local Swift Package over XCFramework:**
- Xcode builds it as part of the project — no separate build step
- Easy to update llama.cpp (just update the git submodule)
- Supports incremental builds
- The C++ interop is cleaner with modulemaps in SPM
- XCFramework requires pre-building for each architecture, more CI complexity

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

> **Important gotcha:** llama.cpp's source file list changes between releases. You'll need to audit which `.c`/`.cpp` files are needed when updating. Reference the llama.cpp CMakeLists.txt for the current file list. The list above is illustrative — the actual set of source files depends on the llama.cpp version you vendor.

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

**Why SwiftData over alternatives:**
- **vs Core Data:** SwiftData is the modern replacement, simpler API, macro-based, better SwiftUI integration. iOS 17+ target makes this viable.
- **vs flat JSON:** No query capability, no migration support, manual serialization. Fine for a manifest but not for conversation history that could grow large.
- **vs SQLite (direct):** SwiftData gives us the query power without raw SQL boilerplate.

**Settings — UserDefaults (via AppStorage):**

Settings are simple key-value pairs. No need for heavier persistence:

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

**Auth considerations:** The HF API is publicly accessible for public repos without authentication. No API key needed for browsing and downloading public GGUF models. Rate limits are generous for unauthenticated requests (~reasonable for an app's usage). If rate limiting becomes an issue, users could optionally provide a HF token in settings.

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

**Download queue strategy:** Serial downloads (one at a time). GGUF files are 2-8 GB. Concurrent downloads would saturate bandwidth and risk iOS killing the app for excessive resource use. Queue additional downloads and start the next when one finishes.

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

- **LlamaContext is a Swift `actor`** — serializes access, prevents concurrent inference calls
- **Inference runs in `Task.detached`** — never blocks the actor or main thread
- **Tokens stream via `AsyncStream`** — clean backpressure, natural cancellation
- **Cancel flag** — volatile bool pointer shared with C++ for immediate stop

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

**Keeping models "warm":** The model stays loaded in the `InferenceService.context` property between conversations. To handle memory pressure:

```swift
// In AppState or InferenceService init
NotificationCenter.default.addObserver(
    forName: UIApplication.didReceiveMemoryWarningNotification,
    object: nil, queue: .main
) { [weak self] _ in
    Task { await self?.inferenceService.unloadModel() }
}
```

Strategy: Keep the model loaded until (a) the user switches models, (b) a memory warning fires, or (c) the app backgrounds for >60 seconds. On relaunch or return from background, reload lazily when the user sends a message.

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

> **Note:** Different model families use different chat templates. The prompt builder should be template-aware. Store the template type as metadata on the model (Llama, ChatML, Phi, etc.) and switch formatting accordingly.

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

**Chat View — streaming display:**

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
| Debug symbols | Full, step into C++ code | Requires dSYM management |
| CI complexity | Low — just `xcodebuild` | High — separate build script per arch |
| Initial setup | More work to get Package.swift right | Simpler if you have a working build |

**Tradeoff:** The Package.swift for llama.cpp is fiddly to get right (source file lists, header search paths, Metal framework linking). But once working, it's far easier to maintain. Reference LLM Farm's approach — they use a similar local package pattern.

### 2. Keeping a model "warm" in memory?

**Strategy: Hold the `LlamaContext` in `InferenceService`, release on memory warning.**

- Keep the model loaded between conversations. Loading a 4GB model takes 2-5 seconds; users will notice if they have to wait each time.
- Register for `didReceiveMemoryWarningNotification` and unload immediately.
- When the app backgrounds, start a 60-second timer. If the app doesn't foreground within that window, unload. This prevents iOS from killing the app for excessive background memory use.
- For context: a Q4_K_M 7B model uses ~4GB RAM. iPhone 15 Pro has 8GB total, ~5-6GB available to apps. This leaves headroom, but a Q4_K_M 13B model (~7.5GB) will be tight. The device gating feature (Phase 3) should prevent users from downloading models that won't fit.

### 3. App Store considerations for large post-install downloads?

Key guidelines to comply with:

- **Guideline 2.5.4:** Apps that download code (executable) may be rejected. GGUF model files are **data files, not executable code** — they're weight matrices. This is the same as downloading images or audio. However, clearly present models as "data" in any review notes.
- **Guideline 4.2.3:** The app must be functional on launch (without downloads). Include a clear onboarding flow that guides users to download their first model. Consider bundling a tiny model (~100MB) for instant first-run experience, or make it clear the app requires a download to function (like a podcast app needs episodes).
- **Review note to submit:** "Hearth AI is a local AI chat application. Model files are neural network weight data (GGUF format) downloaded from Hugging Face Hub. These are not executable code. All inference runs on-device using the open-source llama.cpp library. No user data leaves the device."
- **Storage:** Use `Application Support` directory (not Documents or Caches). Mark files with `isExcludedFromBackup = true` to prevent multi-GB iCloud backups.
- **NSAppTransportSecurity:** huggingface.co uses HTTPS — no ATS exceptions needed.

### 4. Quantization recommendations by device?

| Device | RAM | Recommended Quants | Max Model Size |
|--------|-----|-------------------|----------------|
| iPhone 13 Pro / 14 Pro | 6 GB | Q4_K_M (1-3B), Q4_K_S (7B) | ~3.5 GB file |
| iPhone 15 Pro / 16 Pro | 8 GB | Q4_K_M (7B), Q5_K_M (3B) | ~5 GB file |
| iPhone 16 Pro Max | 8 GB | Q4_K_M (7B), Q5_K_M (7B) | ~5.5 GB file |
| iPad Pro M-series | 8-16 GB | Q5_K_M (7B), Q8_0 (7B), Q4_K_M (13B) | ~8 GB file |

**Rule of thumb for device gating:** Model file size + 2GB overhead < total device RAM. Query available RAM with `os_proc_available_memory()` at runtime.

**Recommended defaults for the "Featured Models" section:**
- **Starter:** Phi-3-mini-4k (3.8B, Q4_K_M, ~2.2GB) — works on all supported devices
- **Standard:** Llama-3.2-3B-Instruct (Q4_K_M, ~1.8GB) — excellent quality/size ratio
- **Advanced:** Mistral-7B-Instruct (Q4_K_M, ~4.1GB) — 8GB+ devices only
- **Power:** Qwen2.5-7B-Instruct (Q4_K_M, ~4.4GB) — 8GB+ devices only

### 5. Conversation history — per-model or global?

**Recommendation: Global conversations, each tagged with the model used.**

- Conversations are stored globally in SwiftData with a `modelId` field.
- Users can view all conversations or filter by model.
- If a model is deleted, conversations remain visible (as read-only history) but can't be continued until another model is loaded.
- **Retention strategy:** Keep all conversations indefinitely (they're just text, very small). Provide a "Delete All Conversations" option in settings and swipe-to-delete on individual conversations.

---

## Phased Roadmap

### Phase 1: Core Inference (Weeks 1-3)

**Goal:** llama.cpp running on-device, one bundled test model, basic chat UI that streams tokens.

**Tasks:**

1. **Xcode project setup**
   - Create new iOS 17+ SwiftUI project
   - Set up folder structure per the plan above
   - Add `.gitignore` for Xcode, Swift, and GGUF files

2. **llama.cpp local package**
   - Create `Packages/LlamaCpp/` directory structure
   - Add llama.cpp as a git submodule in `vendored/`
   - Write `Package.swift` with correct source files and Metal linking
   - Write `llama_bridge.h` and `llama_bridge.cpp`
   - Write `LlamaContext.swift` with `AsyncStream` token streaming
   - Test: build the package standalone, verify Metal acceleration works

3. **InferenceService**
   - Implement `InferenceService` with `loadModel()`, `unloadModel()`, `generate()`
   - Implement memory warning observer for automatic unload
   - Test: load a model, generate text, verify tokens stream

4. **Basic Chat UI**
   - `ChatView` with message list and input bar
   - `MessageBubble` component (user vs assistant styling)
   - `ChatViewModel` that bridges `InferenceService` to UI
   - Streaming text display with auto-scroll
   - Stop generation button

5. **Bundle a test model**
   - Download a small GGUF (~100MB, e.g., TinyLlama-1.1B Q4_K_M) into the project for testing
   - Add to app bundle for Phase 1 testing only (remove before Phase 2)

**Gotchas:**
- llama.cpp Metal shaders need to be bundled. Check that `ggml-metal.metal` is included in the build. You may need to add it as a resource in the SPM target or copy it via a build phase.
- The first build will be slow (llama.cpp compilation). Subsequent builds are incremental.
- Test on a **real device** early. Simulator does not support Metal GPU inference.

**Deliverable:** App launches, loads a bundled model, user can type a message and see streaming AI response.

---

### Phase 2: Model Store & Downloads (Weeks 4-6)

**Goal:** Users can browse HF Hub, download GGUF models, manage local storage.

**Tasks:**

1. **HuggingFaceAPI service**
   - Implement `searchModels()`, `listFiles()`, `downloadURL()`
   - Parse HF API responses into `HFModelInfo` and `HFFileInfo` structs
   - Handle pagination, error states

2. **Download service**
   - Implement `DownloadService` with background URLSession
   - Pause/resume/cancel support
   - File move from temp to `Application Support/Models/`
   - Download queue (serial)
   - Reconnect to in-progress downloads on app relaunch (URLSession background session recreation)

3. **SwiftData persistence**
   - Define `LocalModel` SwiftData schema
   - Save model metadata on successful download
   - Delete model files + records

4. **Model Store UI**
   - `ModelStoreView` with search bar and results grid
   - `ModelCardView` showing name, size, quant, download count
   - `ModelDetailView` with full metadata and download button
   - `FeaturedModelsSection` with curated picks (loaded from bundled JSON)
   - Download progress UI (progress bar, pause/cancel buttons)

5. **Library / Storage UI**
   - `LibraryView` listing downloaded models
   - Delete model (swipe or button)
   - `StorageDashboard` showing per-model and total storage usage
   - Available device storage display

6. **TabView navigation**
   - Switch from single-view to TabView (Chat, Models, Settings)
   - Model selector in Chat view (pick from downloaded models)

**Gotchas:**
- Background URLSession delegates fire even when the app is suspended. Implement `application(_:handleEventsForBackgroundURLSession:completionHandler:)` in the App Delegate (or use the SwiftUI equivalent `.backgroundTask`) to handle completion.
- HF API returns all files in a repo. Filter to only show `.gguf` files.
- Some HF repos have many quantization variants. Group by quantization level in the UI.
- Test download behavior when the app is killed mid-download. Background URLSession should resume.

**Deliverable:** Users can browse HF Hub, download models, see them in their library, select a model, and chat with it.

---

### Phase 3: Polish & Hardening (Weeks 7-9)

**Goal:** Device gating, thermal awareness, conversation history, settings, production UX.

**Tasks:**

1. **Device compatibility gating**
   - Query `os_proc_available_memory()` at runtime
   - Compare against model file size + 2GB overhead
   - Show warning on `ModelDetailView` if model likely won't fit
   - Disable download button for models that definitely won't work

2. **Thermal monitoring**
   - Implement `ThermalMonitor`
   - Show warning banner in Chat when thermal state is `.serious`
   - Auto-pause generation on `.critical` (or reduce token speed)
   - Surface suggestion: "Your device is warm. Consider a smaller model."

3. **Conversation history**
   - Define `Conversation` and `Message` SwiftData models
   - Save conversations automatically after each assistant response
   - Conversation list sidebar/drawer in Chat
   - New conversation, delete conversation, rename conversation
   - Conversation continuity — load previous messages when reopening

4. **Chat enhancements**
   - Copy message to clipboard (long press or button)
   - Regenerate last response
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
   - Model file corruption detection (basic: check file size matches expected)
   - Network error handling in Model Store (retry, offline state)
   - Graceful handling of model load failure
   - App lifecycle: save state on background, restore on foreground

**Gotchas:**
- `os_proc_available_memory()` returns available memory *right now*, which varies. Use it as a guideline, not a hard gate.
- Different model families need different chat templates. Build a registry mapping model family → template formatter. Get this wrong and models will produce garbled output.
- Thermal state `.critical` means iOS may kill the app. Take it seriously.

**Deliverable:** Full-featured app with conversation history, device awareness, settings, polished UX.

---

### Phase 4: App Store Prep (Weeks 10-11)

**Goal:** TestFlight, App Store submission, metadata, review preparation.

**Tasks:**

1. **App Store metadata**
   - App name: "Hearth AI"
   - Subtitle: "Private AI Chat, On-Device"
   - Description highlighting privacy, no cloud, no data collection
   - Keywords: AI, chat, private, offline, local, LLM
   - Screenshots (iPhone 15 Pro, iPhone 16 Pro Max sizes minimum)
   - App icon (warm, hearth/fireplace aesthetic)

2. **Privacy & compliance**
   - Privacy Nutrition Label: "Data Not Collected" (no analytics, no tracking)
   - No App Tracking Transparency prompt needed (no tracking)
   - Privacy Policy URL (can be a simple page: "Hearth AI collects no data")
   - Export compliance: llama.cpp uses standard algorithms, likely qualifies for encryption exemption (ERN). File the self-classification in App Store Connect.

3. **TestFlight**
   - Internal testing group
   - Test on: iPhone 13 Pro, iPhone 15 Pro, iPhone 16 Pro (different RAM tiers)
   - Test scenarios:
     - Fresh install → download model → chat
     - Background download → app killed → relaunch (download should continue)
     - Memory pressure during inference
     - Thermal throttling during extended generation
     - Storage full scenario
     - Airplane mode with downloaded models (should work fully)

4. **Review preparation**
   - Review notes explaining GGUF files are data, not code
   - Demo account not needed (no accounts in the app)
   - Ensure app is functional on first launch (even without models — show onboarding)
   - Verify no private API usage

5. **Performance optimization**
   - Profile with Instruments: Metal System Trace, Time Profiler
   - Ensure Metal GPU inference is actually being used (not CPU fallback)
   - Optimize ScrollView performance for long conversations (LazyVStack)
   - Test with large models (7B) for memory stability

**Gotchas:**
- First submission of an app like this may get additional scrutiny. Be prepared for reviewer questions.
- Apple may flag the app for review if it downloads files >200MB over cellular. Consider adding a WiFi-only download option or warning.
- The app binary itself should be small (<50MB). All the weight is in downloaded models.

**Deliverable:** App on TestFlight, then submitted to App Store.

---

## Risks & Mitigations

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|-----------|--------|------------|
| 1 | **llama.cpp SPM build breaks on update** | High | Medium | Pin to a specific llama.cpp commit. Update deliberately. Keep a working reference build. |
| 2 | **App rejected for "downloading executable code"** | Medium | High | Prepare clear review notes. GGUF files are weight data, not code. Reference precedent (other GGUF apps exist on App Store). |
| 3 | **OOM crash on large models** | High | High | Device gating, `os_proc_available_memory()` checks before load, memory warning observer to unload. Conservative RAM estimates. |
| 4 | **Metal shader missing from bundle** | Medium | High | Verify `ggml-metal.metal` is included in the build. Test on device (not simulator). Add build-phase copy if SPM doesn't handle it. |
| 5 | **Background download reliability** | Medium | Medium | Use proper background URLSession. Handle `handleEventsForBackgroundURLSession`. Test app-killed-during-download scenario. |
| 6 | **HF API rate limiting** | Low | Medium | Cache search results. Add optional HF token support. Implement exponential backoff. |
| 7 | **Thermal throttling degrades UX** | Medium | Medium | Monitor thermal state. Warn users. Suggest smaller models. Auto-reduce generation speed at `.serious`. |
| 8 | **Chat template mismatches** | High | Medium | Build template registry from day one. Test each featured model with its correct template. Default to ChatML if unknown. |
| 9 | **Model file corruption** | Low | Low | Verify file size after download. Checksum validation if HF provides SHA256 (they do in the API). Re-download option. |
| 10 | **llama.cpp source files change between versions** | High | Medium | Audit llama.cpp CMakeLists.txt when updating. Consider a script that generates the SPM source file list from CMakeLists.txt. |

---

## Summary

Hearth AI is architecturally straightforward: a SwiftUI MVVM app with a local Swift Package wrapping llama.cpp, SwiftData for persistence, and background URLSession for downloads. The complexity lives in three areas:

1. **Getting llama.cpp to build and run correctly in SPM** — fiddly but solvable, and the reference projects (LLM Farm) prove it works.
2. **Memory management** — keeping models warm while respecting iOS memory limits requires careful lifecycle management.
3. **Chat template correctness** — different model families need different prompt formatting, and getting this wrong produces bad output.

The four-phase plan gets to a working chat app in ~3 weeks, a full-featured app in ~9 weeks, and App Store in ~11 weeks. Each phase has a concrete deliverable that can be tested independently.
