import SwiftUI
import SwiftData

@main
struct HearthAIApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(appState.inferenceService)
        }
        .modelContainer(for: [
            LocalModel.self,
            Conversation.self,
            Message.self,
        ])
    }
}
