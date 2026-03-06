import SwiftUI
import SwiftData

@main
struct HearthAIApp: App {
    @State private var appState = AppState()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(appState.inferenceService)
                .environment(appState.downloadService)
                .environment(appState.networkMonitor)
                .onAppear {
                    setupDownloadCompletion()
                    if !hasCompletedOnboarding {
                        showOnboarding = true
                    }
                }
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingView(isPresented: $showOnboarding)
                        .onDisappear {
                            hasCompletedOnboarding = true
                        }
                }
        }
        .modelContainer(for: [
            LocalModel.self,
            Conversation.self,
            Message.self,
        ])
    }

    private func setupDownloadCompletion() {
        appState.downloadService.onDownloadComplete = { [appState] info in
            saveDownloadedModel(info: info, appState: appState)
        }
    }

    @MainActor
    private func saveDownloadedModel(info: DownloadInfo, appState: AppState) {
        guard let container = try? ModelContainer(for: LocalModel.self) else { return }
        let context = container.mainContext

        let repoComponent = info.repoId.replacingOccurrences(of: "/", with: "_")
        let localPath = "\(repoComponent)/\(info.fileName)"

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
            fileSizeBytes: info.fileSize,
            localPath: localPath
        )

        context.insert(model)
        try? context.save()
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
