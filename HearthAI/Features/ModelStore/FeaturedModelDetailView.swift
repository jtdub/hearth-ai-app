import SwiftUI
import SwiftData

struct FeaturedModelDetailView: View {
    let model: FeaturedModel
    @Environment(DownloadService.self) private var downloadService
    @Query private var localModels: [LocalModel]

    private var isDownloaded: Bool {
        localModels.contains { $0.id == model.id }
    }

    private var activeDownload: DownloadInfo? {
        downloadService.downloads[model.id]
    }

    var body: some View {
        List {
            Section("Model Info") {
                LabeledContent("Name", value: model.displayName)
                LabeledContent("Family", value: model.modelFamily)
                LabeledContent("Repository", value: model.repoId)
                LabeledContent("Quantization", value: model.quantization)
                LabeledContent("Size", value: model.formattedSize)
            }

            Section("Description") {
                Text(model.description)
                    .font(.body)
            }

            Section {
                if isDownloaded {
                    Label("Downloaded", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if let download = activeDownload {
                    DownloadProgressRow(download: download)
                } else {
                    Button {
                        downloadService.startDownload(
                            repoId: model.repoId,
                            fileName: model.fileName,
                            fileSize: model.sizeBytes
                        )
                    } label: {
                        Label(
                            "Download (\(model.formattedSize))",
                            systemImage: "arrow.down.circle"
                        )
                    }
                }
            }
        }
        .navigationTitle(model.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
