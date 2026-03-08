import SwiftUI
import SwiftData

struct ModelPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(InferenceService.self) private var inferenceService
    @Query(sort: \LocalModel.downloadedAt, order: .reverse) private var models: [LocalModel]
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            Group {
                if models.isEmpty {
                    ContentUnavailableView(
                        "No Models",
                        systemImage: "square.stack.3d.up.slash",
                        description: Text("Download a model from the Models tab first.")
                    )
                    .onAppear {
                        print("🔍 ModelPickerSheet: Query returned 0 models")
                    }
                } else {
                    List(models) { model in
                        Button {
                            loadModel(model)
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
                                }
                            }
                        }
                        .disabled(inferenceService.isLoading)
                    }
                    .onAppear {
                        print("✅ ModelPickerSheet: Query found \(models.count) model(s)")
                        for model in models {
                            print("   - \(model.displayName) (\(model.fileName))")
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
                            Task { await inferenceService.unloadModel() }
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
        }
    }

    private func loadModel(_ model: LocalModel) {
        Task {
            do {
                try await inferenceService.loadModel(model)
                dismiss()
            } catch {
                loadError = error.localizedDescription
            }
        }
    }
}
