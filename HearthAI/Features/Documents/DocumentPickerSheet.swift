import SwiftUI
import SwiftData

/// Sheet for selecting a document to attach to a chat conversation.
struct DocumentPickerSheet: View {
    let onSelect: (Document) -> Void
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Document.importedAt, order: .reverse)
    private var documents: [Document]

    var body: some View {
        NavigationStack {
            Group {
                if documents.isEmpty {
                    ContentUnavailableView {
                        Label(
                            "No Documents",
                            systemImage: "doc.text.magnifyingglass"
                        )
                    } description: {
                        Text(
                            "Import documents from the Documents "
                            + "tab to use them in chat."
                        )
                    }
                } else {
                    List(documents) { document in
                        Button {
                            onSelect(document)
                            dismiss()
                        } label: {
                            DocumentRow(document: document)
                        }
                    }
                }
            }
            .navigationTitle("Attach Document")
            #if os(macOS)
            .frame(minWidth: 400, minHeight: 300)
            #else
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
