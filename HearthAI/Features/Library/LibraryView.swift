import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(InferenceService.self) private var inferenceService
    @Query(sort: \LocalModel.downloadedAt, order: .reverse) private var models: [LocalModel]
    @State private var modelToDelete: LocalModel?

    var body: some View {
        NavigationStack {
            Group {
                if models.isEmpty {
                    emptyState
                } else {
                    modelList
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    storageInfo
                }
            }
            .alert("Delete Model?", isPresented: .init(
                get: { modelToDelete != nil },
                set: { if !$0 { modelToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) { modelToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let model = modelToDelete {
                        deleteModel(model)
                    }
                }
            } message: {
                if let model = modelToDelete {
                    let size = ByteCountFormatter.string(
                        fromByteCount: model.fileSizeBytes, countStyle: .file
                    )
                    Text("This will delete \(model.displayName) (\(size)) from your device.")
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No Models",
            systemImage: "square.stack.3d.up.slash",
            description: Text("Download models from the Models tab to get started.")
        )
    }

    // MARK: - Model List

    private var modelList: some View {
        List {
            Section {
                ForEach(models) { model in
                    ModelRow(
                        model: model,
                        isLoaded: inferenceService.loadedModelId == model.id
                    )
                }
                .onDelete { indexSet in
                    if let index = indexSet.first {
                        modelToDelete = models[index]
                    }
                }
            } footer: {
                Text("\(models.count) model\(models.count == 1 ? "" : "s"), \(totalSizeFormatted)")
            }

            Section("Storage") {
                storageDashboard
            }
        }
    }

    // MARK: - Storage

    private var storageInfo: some View {
        let available = FileManager.availableDiskSpace
        return Text(ByteCountFormatter.string(fromByteCount: available, countStyle: .file) + " free")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var storageDashboard: some View {
        VStack(alignment: .leading, spacing: 8) {
            let totalUsed = models.reduce(Int64(0)) { $0 + $1.fileSizeBytes }
            let available = FileManager.availableDiskSpace

            LabeledContent("Models Storage") {
                Text(ByteCountFormatter.string(fromByteCount: totalUsed, countStyle: .file))
            }
            LabeledContent("Available Space") {
                Text(ByteCountFormatter.string(fromByteCount: available, countStyle: .file))
            }

            if available < 1_000_000_000 {
                Label(
                    "Low storage. Consider removing unused models.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }
        }
    }

    private var totalSizeFormatted: String {
        let total = models.reduce(Int64(0)) { $0 + $1.fileSizeBytes }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    // MARK: - Actions

    private func deleteModel(_ model: LocalModel) {
        let fileURL = model.absolutePath
        let isLoaded = inferenceService.loadedModelId == model.id
        Task { @MainActor in
            if isLoaded {
                await inferenceService.unloadModel()
            }
            try? FileManager.default.removeItem(at: fileURL)
            modelContext.delete(model)
            try? modelContext.save()
            modelToDelete = nil
        }
    }
}

struct ModelRow: View {
    let model: LocalModel
    let isLoaded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(model.displayName)
                    .font(.headline)
                if isLoaded {
                    Text("Active")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.2))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }
            }
            HStack(spacing: 12) {
                Label(
                    ByteCountFormatter.string(
                        fromByteCount: model.fileSizeBytes, countStyle: .file
                    ),
                    systemImage: "doc"
                )
                Label(model.quantization, systemImage: "cpu")
                Label(model.modelFamily, systemImage: "brain")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            if let lastUsed = model.lastUsedAt {
                Text("Last used \(lastUsed.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    LibraryView()
        .environment(InferenceService())
        .modelContainer(for: LocalModel.self, inMemory: true)
}
