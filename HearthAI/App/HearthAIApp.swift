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
            let config: ModelConfiguration
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
                config = ModelConfiguration(isStoredInMemoryOnly: true)
            } else {
                config = ModelConfiguration(
                    groupContainer: .identifier(
                        AppGroupConstants.groupId
                    )
                )
            }
            modelContainer = try ModelContainer(
                for: LocalModel.self, Conversation.self, Message.self,
                Document.self, DocumentChunk.self, Memory.self,
                configurations: config
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
                .modelContainer(modelContainer)
                .onAppear {
                    setupDownloadCompletion()
                    syncModelList()
                    registerExistingModels()
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
    private func registerExistingModels() {
        let modelsDir = FileManager.modelsDirectory
        let context = modelContainer.mainContext

        guard let enumerator = FileManager.default.enumerator(
            at: modelsDir,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var registeredCount = 0

        for case let fileURL as URL in enumerator
        where fileURL.pathExtension.lowercased() == "gguf" {
            guard let isDir = try? fileURL.resourceValues(
                forKeys: [.isDirectoryKey]
            ).isDirectory, !isDir else {
                continue
            }

            let fileName = fileURL.lastPathComponent
            let relativePath = fileURL.path.replacingOccurrences(
                of: modelsDir.path + "/", with: ""
            )

            if isModelRegistered(
                fileName: fileName,
                relativePath: relativePath,
                context: context
            ) {
                continue
            }

            let attrs = try? FileManager.default.attributesOfItem(
                atPath: fileURL.path
            )
            let fileSize = (attrs?[.size] as? Int64) ?? 0
            let downloadDate = (attrs?[.creationDate] as? Date) ?? Date()

            let model = LocalModel(
                id: UUID().uuidString,
                repoId: extractRepoId(
                    from: relativePath, fileName: fileName
                ),
                fileName: fileName,
                displayName: fileName
                    .replacingOccurrences(of: ".gguf", with: "")
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: "_", with: " "),
                modelFamily: guessModelFamily(fileName),
                quantization: guessQuantization(fileName),
                fileSizeBytes: fileSize,
                downloadedAt: downloadDate,
                localPath: relativePath
            )

            context.insert(model)
            registeredCount += 1
        }

        if registeredCount > 0 {
            try? context.save()
        }

        cleanupMissingModels(context: context)
    }

    @MainActor
    private func isModelRegistered(
        fileName: String,
        relativePath: String,
        context: ModelContext
    ) -> Bool {
        let descriptor = FetchDescriptor<LocalModel>(
            predicate: #Predicate { model in
                model.fileName == fileName
                    || model.localPath == relativePath
            }
        )

        if let existing = try? context.fetch(descriptor).first {
            if existing.localPath != relativePath {
                existing.localPath = relativePath
                try? context.save()
            }
            return true
        }
        return false
    }

    @MainActor
    private func cleanupMissingModels(context: ModelContext) {
        guard let allModels = try? context.fetch(
            FetchDescriptor<LocalModel>()
        ) else { return }

        var removedCount = 0
        for model in allModels
        where !FileManager.default.fileExists(
            atPath: model.absolutePath.path
        ) {
            context.delete(model)
            removedCount += 1
        }

        if removedCount > 0 {
            try? context.save()
        }
    }

    private func extractRepoId(
        from relativePath: String, fileName: String
    ) -> String {
        let components = relativePath.split(separator: "/")
        if components.count > 1 {
            return components.dropLast().joined(separator: "/")
                .replacingOccurrences(of: "_", with: "/")
        }
        return "local/unknown"
    }

    @MainActor
    private func saveDownloadedModel(
        info: DownloadInfo, appState: AppState
    ) {
        let context = modelContainer.mainContext

        let repoComponent = info.repoId
            .replacingOccurrences(of: "/", with: "_")
        let localPath = "\(repoComponent)/\(info.fileName)"

        let fileURL = FileManager.modelsDirectory
            .appendingPathComponent(localPath)
        let actualSize: Int64
        if let attrs = try? FileManager.default.attributesOfItem(
            atPath: fileURL.path
        ), let size = attrs[.size] as? Int64 {
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
        modelSync.syncModels(context: context)
    }

    private func guessModelFamily(_ nameOrRepoId: String) -> String {
        let name = nameOrRepoId.lowercased()
        let families = [
            ("tinyllama", "TinyLlama"),
            ("llama-3", "Llama 3"),
            ("llama-2", "Llama 2"),
            ("codellama", "CodeLlama"),
            ("llama", "Llama"),
            ("mistral", "Mistral"),
            ("phi", "Phi"),
            ("qwen", "Qwen"),
            ("gemma", "Gemma"),
            ("smollm", "SmolLM"),
            ("openhermes", "OpenHermes"),
            ("hermes", "Hermes"),
            ("vicuna", "Vicuna"),
            ("orca", "Orca")
        ]

        for (key, value) in families where name.contains(key) {
            return value
        }

        return "Unknown"
    }

    private func guessQuantization(_ fileName: String) -> String {
        let name = fileName.lowercased()
        let quants = [
            "q2_k", "q3_k_s", "q3_k_m", "q3_k_l",
            "q4_0", "q4_1", "q4_k_s", "q4_k_m",
            "q5_0", "q5_1", "q5_k_s", "q5_k_m",
            "q6_k", "q8_0", "f16", "f32",
        ]
        return quants.first { name.contains($0) }?.uppercased()
            ?? "Unknown"
    }
}
