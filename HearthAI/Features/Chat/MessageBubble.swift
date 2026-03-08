import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct MessageBubble: View {
    let role: MessageRole
    let content: String
    @State private var showCopied = false

    init(message: ChatMessage) {
        self.role = message.role
        self.content = message.content
    }

    init(role: MessageRole, content: String) {
        self.role = role
        self.content = content
    }

    var body: some View {
        HStack {
            if role == .user { Spacer(minLength: 48) }

            VStack(alignment: role == .user ? .trailing : .leading, spacing: 4) {
                Text(role == .user ? "You" : "Hearth")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleColor, in: bubbleShape)
                    .foregroundStyle(role == .user ? .white : .primary)
                    .textSelection(.enabled)
                    .contextMenu {
                        Button {
                            copyToClipboard(content)
                            showCopied = true
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if showCopied {
                            Text("Copied")
                                .font(.caption2)
                                .padding(4)
                                .background(.ultraThinMaterial, in: Capsule())
                                .transition(.opacity)
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        withAnimation { showCopied = false }
                                    }
                                }
                        }
                    }
            }

            if role == .assistant { Spacer(minLength: 48) }
        }
    }

    private var bubbleColor: Color {
        #if canImport(UIKit)
        role == .user ? .accentColor : Color(.systemGray5)
        #else
        role == .user ? .accentColor : Color(nsColor: .controlBackgroundColor)
        #endif
    }

    private var bubbleShape: some Shape {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
    }

    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

#Preview {
    VStack(spacing: 12) {
        MessageBubble(role: .user, content: "Hello, how are you?")
        MessageBubble(role: .assistant, content: "I'm doing well! How can I help you today?")
    }
    .padding()
}
