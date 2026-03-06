import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ChatView()
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }

            ModelStoreView()
                .tabItem { Label("Models", systemImage: "square.grid.2x2") }

            LibraryView()
                .tabItem { Label("Library", systemImage: "internaldrive") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .environment(InferenceService())
        .environment(DownloadService())
        .environment(NetworkMonitor())
}
