import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if os(iOS) || os(visionOS)
import PhotosUI
#endif

struct DocumentsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Document.importedAt, order: .reverse)
    private var documents: [Document]
    @State private var importViewModel = DocumentImportViewModel()
    @State private var showFileImporter = false
    #if os(iOS) || os(visionOS)
    @State private var showPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    #endif

    var body: some View {
        NavigationStack {
            Group {
                if documents.isEmpty {
                    emptyState
                } else {
                    documentList
                }
            }
            .navigationTitle("Documents")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    importMenu
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: supportedTypes,
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .overlay {
                if importViewModel.isImporting {
                    importingOverlay
                }
            }
            .alert(
                "Import Error",
                isPresented: .init(
                    get: { importViewModel.importError != nil },
                    set: { if !$0 { importViewModel.importError = nil } }
                )
            ) {
                Button("OK") { importViewModel.importError = nil }
            } message: {
                if let error = importViewModel.importError {
                    Text(error)
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Documents", systemImage: "doc.text.magnifyingglass")
        } description: {
            Text("Import PDFs, text files, or photos to ask questions about them.")
        } actions: {
            Button("Import Document") {
                showFileImporter = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var documentList: some View {
        List {
            ForEach(documents) { document in
                NavigationLink {
                    DocumentDetailView(document: document)
                } label: {
                    DocumentRow(document: document)
                }
            }
            .onDelete(perform: deleteDocuments)
        }
    }

    private var importMenu: some View {
        Menu {
            Button {
                showFileImporter = true
            } label: {
                Label("Import File", systemImage: "doc")
            }
            #if os(iOS) || os(visionOS)
            Button {
                showPhotoPicker = true
            } label: {
                Label("Scan Photo (OCR)", systemImage: "camera")
            }
            #endif
        } label: {
            Label("Import", systemImage: "plus")
        }
        #if os(iOS) || os(visionOS)
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhoto,
            matching: .images
        )
        .onChange(of: selectedPhoto) { _, newValue in
            if let item = newValue {
                Task {
                    await importViewModel.importPhoto(
                        from: item, context: modelContext
                    )
                    selectedPhoto = nil
                }
            }
        }
        #endif
    }

    private var importingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                Text("Importing document...")
                    .font(.headline)
            }
            .padding(32)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var supportedTypes: [UTType] {
        [.pdf, .plainText, .rtf, .utf8PlainText]
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await importViewModel.importFile(
                    from: url, context: modelContext
                )
            }
        case .failure(let error):
            importViewModel.importError = error.localizedDescription
        }
    }

    private func deleteDocuments(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(documents[index])
        }
        try? modelContext.save()
    }
}

struct DocumentRow: View {
    let document: Document

    var body: some View {
        HStack {
            Image(systemName: document.documentSourceType.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(document.title)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(document.documentSourceType.displayName)
                    Text(formattedSize)
                    Text("\(document.chunkCount) chunks")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var formattedSize: String {
        ByteCountFormatter.string(
            fromByteCount: document.fileSize, countStyle: .file
        )
    }
}
