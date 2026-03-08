import SwiftUI

struct DocumentDetailView: View {
    let document: Document
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                metadataSection
                textPreviewSection
            }
            .padding()
        }
        .navigationTitle(document.title)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .confirmationDialog(
            "Delete Document",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                modelContext.delete(document)
                try? modelContext.save()
                dismiss()
            }
        } message: {
            Text("This will permanently delete the document and its chunks.")
        }
    }

    private var metadataSection: some View {
        GroupBox("Details") {
            VStack(alignment: .leading, spacing: 8) {
                metadataRow("Type", document.documentSourceType.displayName)
                metadataRow("Size", formattedSize)
                metadataRow("Words", "\(document.wordCount)")
                metadataRow("Chunks", "\(document.chunkCount)")
                if let pages = document.pageCount {
                    metadataRow("Pages", "\(pages)")
                }
                metadataRow("Imported", formattedDate)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var textPreviewSection: some View {
        GroupBox("Extracted Text") {
            Text(document.rawText.prefix(5000))
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            if document.rawText.count > 5000 {
                Text("... (\(document.rawText.count - 5000) more characters)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func metadataRow(
        _ label: String, _ value: String
    ) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
        }
        .font(.subheadline)
    }

    private var formattedSize: String {
        ByteCountFormatter.string(
            fromByteCount: document.fileSize, countStyle: .file
        )
    }

    private var formattedDate: String {
        document.importedAt.formatted(
            date: .abbreviated, time: .shortened
        )
    }
}
