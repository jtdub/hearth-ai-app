import SwiftUI

struct MessageBubble: View {
    let role: MessageRole
    let content: String

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
            }

            if role == .assistant { Spacer(minLength: 48) }
        }
    }

    private var bubbleColor: Color {
        role == .user ? .accentColor : Color(.systemGray5)
    }

    private var bubbleShape: some Shape {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
    }
}

#Preview {
    VStack(spacing: 12) {
        MessageBubble(role: .user, content: "Hello, how are you?")
        MessageBubble(role: .assistant, content: "I'm doing well! How can I help you today?")
    }
    .padding()
}
