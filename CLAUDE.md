# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Hearth AI is a multi-platform (iOS, macOS, visionOS) app for on-device LLM inference using llama.cpp. It supports browsing/downloading models from Hugging Face Hub, running them locally with Metal GPU acceleration, document Q&A with chunked retrieval, conversation memory with TF-IDF relevance scoring, a Share Extension, and App Intents for Siri/Shortcuts. Zero third-party Swift dependencies beyond the vendored llama.cpp submodule.

## Build & Development

### Prerequisites

- Xcode 16.3+, macOS 15+
- Install XcodeGen: `brew install xcodegen`
- Install SwiftLint: `brew install swiftlint`
- Initialize submodules: `git submodule update --init --recursive`

### Build Steps

```bash
# 1. Build llama.cpp XCFramework (required before first build)
bash scripts/build-xcframework.sh

# 2. Generate Xcode project from project.yml
xcodegen generate

# 3. Build (iOS)
xcodebuild build -project HearthAI.xcodeproj -scheme HearthAI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO EXCLUDED_ARCHS='x86_64'

# 3b. Build (macOS)
xcodebuild build -project HearthAI.xcodeproj -scheme HearthAI \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

### Testing

Uses Swift Testing framework (`@Test` macro), not XCTest.

```bash
# Run all tests
xcodebuild test -project HearthAI.xcodeproj -scheme HearthAI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO EXCLUDED_ARCHS='x86_64' \
  -only-testing:HearthAITests -parallel-testing-enabled YES
```

### Linting

```bash
swiftlint lint --strict
```

SwiftLint runs in strict mode in CI. Key rules:
- Line length: 120 warning / 150 error
- File length: 500 warning / 800 error
- Function body length: 60 warning / 100 error
- Type body length: 300 warning / 500 error
- `force_unwrapping` opt-in rule is enabled — avoid force unwraps
- `trailing_comma` and `opening_brace` rules are disabled

## Architecture

**Pattern:** SwiftUI + MVVM with `@Observable` view models

**Persistence:** SwiftData (`@Model` classes in `HearthAI/Models/`), stored in App Group shared container for extension access

**Project generation:** XcodeGen — edit `project.yml` for target/build setting changes, not the `.xcodeproj` directly. Run `xcodegen generate` after changes.

**Platform guards:** Use `#if os(iOS) || os(visionOS)` for UIKit/PhotosUI-only code (NOT `#if canImport`)

### Key Directories

- `HearthAI/App/` — App entry point and `AppState` (DI container owning all services)
- `HearthAI/Features/` — Feature modules: Chat, ModelStore, Library, Documents, Memory, Settings, AppIntents, SharedProcessing
- `HearthAI/Models/` — SwiftData models: `LocalModel`, `Conversation`, `Message`, `Document`, `DocumentChunk`, `Memory`
- `HearthAI/Services/` — Core services: Inference, Download, HuggingFace API, Thermal monitoring, Document processing, Memory processing
- `HearthAI/Shared/` — Constants, extensions, SharedTypes (shared with Share Extension)
- `HearthAI ShareExtension/` — Share Extension for processing shared text/URLs
- `Packages/LlamaCpp/` — Local Swift package wrapping llama.cpp via XCFramework + C++ bridge
- `scripts/` — Build scripts (XCFramework builder, test model downloader)

### LlamaCpp Package

The `Packages/LlamaCpp/` package wraps the vendored llama.cpp (git submodule at `Packages/LlamaCpp/vendored/llama.cpp`). The XCFramework must be built via `scripts/build-xcframework.sh` before the project will compile. The package links Metal, MetalPerformanceShaders, and Accelerate frameworks for GPU inference.

### Service Layer

- **InferenceService** — Loads GGUF models via LlamaCpp, handles streaming token generation
- **DownloadService** — Background URLSession downloads with progress tracking
- **HuggingFaceAPI** — REST client for browsing HF Hub models
- **DeviceCapability** — RAM-based model compatibility gating
- **ThermalMonitor** — Observes device thermal state to manage inference
- **ChunkingService** — Splits documents into overlapping token-budget chunks
- **ChunkSelectorService** — TF-IDF relevance scoring for document chunk retrieval
- **MemorySelectorService** — TF-IDF relevance scoring for memory retrieval

### Targets

- **HearthAI** — Main app (iOS, macOS, visionOS)
- **HearthAIShareExtension** — Share Extension for processing shared content
- **HearthAITests** — Unit tests using Swift Testing framework

## Deployment

- iOS 17.0 / macOS 14.0 / visionOS 1.0 minimum deployment targets
- Swift 5.9
- Simulator builds exclude x86_64 (arm64 only)
- App Group: `group.ai.hearth.shared` (shared container for SwiftData + extensions)
