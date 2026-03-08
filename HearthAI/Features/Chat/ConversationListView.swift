import SwiftUI
import SwiftData

struct ConversationListView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    let onSelect: (Conversation) -> Void
    let onNew: () -> Void
    let onDelete: (Conversation) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if conversations.isEmpty {
                    ContentUnavailableView(
                        "No Conversations",
                        systemImage: "bubble.left.and.text.bubble.right",
                        description: Text("Start a new chat to begin.")
                    )
                } else {
                    List {
                        ForEach(conversations) { conversation in
                            Button {
                                onSelect(conversation)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(conversation.title)
                                        .font(.headline)
                                        .lineLimit(1)
                                    HStack {
                                        Text("\(conversation.messages.count) messages")
                                        Spacer()
                                        Text(conversation.updatedAt.formatted(
                                            .relative(presentation: .named)
                                        ))
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                onDelete(conversations[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("Conversations")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onNew()
                        dismiss()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}
