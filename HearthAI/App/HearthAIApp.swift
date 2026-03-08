import SwiftUI
import SwiftData

@main
struct HearthAIApp: App {
    @State private var appState = AppState()
    @State private var sharedRequestHandler = SharedRequestHandler()
    private let modelContainer: ModelContainer
    private let modelSync = SharedModelSync()

    init() {
        do {
            modelContainer = try ModelContainer(
                for: LocalModel.self, Conversation.self, Message.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(appState.inferenceService)
                .environment(appState.downloadService)
                .environment(sharedRequestHandler)
                .onAppear {
                    setupDownloadCompletion()
                    syncModelList()
                }
                .onOpenURL { url in
                    sharedRequestHandler.handleURL(url)
                }
                .sheet(item: sharedRequestBinding) { _ in
                    SharedRequestView()
                        .environment(sharedRequestHandler)
                        .environment(appState.inferenceService)
                        .modelContainer(modelContainer)
                }
        }
        #if os(macOS)
        .defaultSize(width: 1000, height: 700)
        #endif
        .modelContainer(modelContainer)

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(appState)
                .environment(appState.inferenceService)
                .environment(appState.downloadService)
                .modelContainer(modelContainer)
        }
        #endif
    }

    private var sharedRequestBinding: Binding<SharedInferenceRequest?> {
        Binding(
            get: { sharedRequestHandler.pendingRequest },
            set: { _ in sharedRequestHandler.dismiss() }
        )
    }

    private func setupDownloadCompletion() {
        appState.downloadService.onDownloadComplete = { [appState] info in
            saveDownloadedModel(info: info, appState: appState)
        }
    }

    @MainActor
    private func syncModelList() {
        modelSync.syncModels(context: modelContainer.mainContext)
    }

    @MainActor
    private func saveDownloadedModel(info: DownloadInfo, appState: AppState) {
        let context = modelContainer.mainContext

        let repoComponent = info.repoId.replacingOccurrences(of: "/", with: "_")
        let localPath = "\(repoComponent)/\(info.fileName)"

        // Use actual file size from disk rather than pre-configured estimate
        let fileURL = FileManager.modelsDirectory.appendingPathComponent(localPath)
        let actualSize: Int64
        if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let size = attrs[.size] as? Int64 {
            actualSize = size
        } else {
            actualSize = info.fileSize
        }

        let model = LocalModel(
            id: info.id,
            repoId: info.repoId,
            fileName: info.fileName,
            displayName: info.fileName
                .replacingOccurrences(of: ".gguf", with: "")
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " "),
            modelFamily: guessModelFamily(info.repoId),
            quantization: guessQuantization(info.fileName),
            fileSizeBytes: actualSize,
            localPath: localPath
        )

        context.insert(model)
        try? context.save()

        // Sync model list to shared container for extensions
        modelSync.syncModels(context: context)
    }

    private func guessModelFamily(_ repoId: String) -> String {
        let name = repoId.lowercased()
        let families = ["llama", "mistral", "phi", "qwen", "gemma", "smollm", "tinyllama"]
        return families.first { name.contains($0) }?.capitalized ?? "Unknown"
    }

    private func guessQuantization(_ fileName: String) -> String {
        let name = fileName.lowercased()
        let quants = [
            "q2_k", "q3_k_s", "q3_k_m", "q3_k_l",
            "q4_0", "q4_1", "q4_k_s", "q4_k_m",
            "q5_0", "q5_1", "q5_k_s", "q5_k_m",
            "q6_k", "q8_0", "f16", "f32",
        ]
        return quants.first { name.contains($0) }?.uppercased() ?? "Unknown"
    }
}
