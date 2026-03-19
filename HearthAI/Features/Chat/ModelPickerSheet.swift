import SwiftUI
import SwiftData

struct ModelPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(InferenceService.self) private var inferenceService
    @Query(sort: \LocalModel.downloadedAt, order: .reverse)
    private var models: [LocalModel]
    @State private var loadError: String?
    @State private var modelToConfirm: LocalModel?

    var body: some View {
        NavigationStack {
            Group {
                if models.isEmpty {
                    ContentUnavailableView(
                        "No Models",
                        systemImage: "square.stack.3d.up.slash",
                        description: Text(
                            "Download a model from the Models tab first."
                        )
                    )
                } else {
                    List {
                        ForEach(models) { model in
                            modelRow(model)
                        }
                        Section {
                            HStack {
                                Text("Available Memory")
                                Spacer()
                                Text(
                                    DeviceCapability
                                        .availableMemoryFormatted
                                )
                                .foregroundStyle(.secondary)
                            }
                            .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Select Model")
            #if os(macOS)
            .frame(minWidth: 400, minHeight: 300)
            #else
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if inferenceService.isModelLoaded {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Unload") {
                            Task {
                                await inferenceService.unloadModel()
                            }
                        }
                    }
                }
            }
            .alert("Load Error", isPresented: .init(
                get: { loadError != nil },
                set: { if !$0 { loadError = nil } }
            )) {
                Button("OK") { loadError = nil }
            } message: {
                Text(loadError ?? "")
            }
            .confirmationDialog(
                "Memory Warning",
                isPresented: .init(
                    get: { modelToConfirm != nil },
                    set: { if !$0 { modelToConfirm = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Load Anyway") {
                    if let model = modelToConfirm {
                        loadModel(model)
                    }
                }
                Button("Cancel", role: .cancel) {
                    modelToConfirm = nil
                }
            } message: {
                Text(
                    DeviceCapability.canRunModel(
                        fileSizeBytes: modelToConfirm?
                            .fileSizeBytes ?? 0
                    ).warningMessage ?? ""
                )
            }
        }
    }

    @ViewBuilder
    private func modelRow(_ model: LocalModel) -> some View {
        let fit = DeviceCapability.canRunModel(
            fileSizeBytes: model.fileSizeBytes
        )
        Button {
            if fit == .tight {
                modelToConfirm = model
            } else {
                loadModel(model)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.headline)
                    HStack(spacing: 8) {
                        Text(model.quantization)
                        Text(ByteCountFormatter.string(
                            fromByteCount: model.fileSizeBytes,
                            countStyle: .file
                        ))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if inferenceService.loadedModelId == model.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if inferenceService.isLoading {
                    ProgressView()
                } else if fit == .tight {
                    Image(
                        systemName: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                } else if fit == .tooLarge {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .disabled(
            inferenceService.isLoading || fit == .tooLarge
        )
    }

    private func loadModel(_ model: LocalModel) {
        Task {
            do {
                try await inferenceService.loadModel(model)
                model.lastUsedAt = .now
                try? modelContext.save()
                dismiss()
            } catch {
                loadError = error.localizedDescription
            }
        }
    }
}
