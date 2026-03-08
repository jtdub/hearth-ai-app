import SwiftUI

enum NavigationItem: Hashable {
    case chat, documents, memory, models, library, settings
}

struct ContentView: View {
    #if os(macOS)
    var body: some View {
        SidebarContentView()
    }
    #else
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .regular {
            SidebarContentView()
        } else {
            TabContentView()
        }
    }
    #endif
}

struct TabContentView: View {
    var body: some View {
        TabView {
            ChatView()
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }

            DocumentsView()
                .tabItem { Label("Documents", systemImage: "doc.text.magnifyingglass") }

            MemoryView()
                .tabItem { Label("Memory", systemImage: "brain.head.profile") }

            ModelStoreView()
                .tabItem { Label("Models", systemImage: "square.grid.2x2") }

            LibraryView()
                .tabItem { Label("Library", systemImage: "internaldrive") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}

struct SidebarContentView: View {
    @State private var selection: NavigationItem? = .chat

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Chat", systemImage: "bubble.left.and.bubble.right")
                    .tag(NavigationItem.chat)
                Label("Documents", systemImage: "doc.text.magnifyingglass")
                    .tag(NavigationItem.documents)
                Label("Memory", systemImage: "brain.head.profile")
                    .tag(NavigationItem.memory)
                Label("Models", systemImage: "square.grid.2x2")
                    .tag(NavigationItem.models)
                Label("Library", systemImage: "internaldrive")
                    .tag(NavigationItem.library)
                Label("Settings", systemImage: "gear")
                    .tag(NavigationItem.settings)
            }
            .navigationTitle("Hearth AI")
        } detail: {
            switch selection {
            case .chat:
                ChatView()
            case .documents:
                DocumentsView()
            case .memory:
                MemoryView()
            case .models:
                ModelStoreView()
            case .library:
                LibraryView()
            case .settings:
                SettingsView()
            case nil:
                ContentUnavailableView(
                    "Select an Item",
                    systemImage: "sidebar.left",
                    description: Text("Choose a section from the sidebar.")
                )
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .environment(InferenceService())
        .environment(DownloadService())
}
