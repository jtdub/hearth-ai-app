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

            memoryWarningSection(fileSize: model.sizeBytes)

            Section {
                if isDownloaded {
                    Label("Downloaded", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if let download = activeDownload {
                    DownloadProgressRow(download: download)
                } else {
                    let fit = DeviceCapability.canRunModel(fileSizeBytes: model.sizeBytes)
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
                    .disabled(!fit.canDownload)
                }
            }
        }
        .navigationTitle(model.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func memoryWarningSection(fileSize: Int64) -> some View {
        let fit = DeviceCapability.canRunModel(fileSizeBytes: fileSize)
        if let warning = fit.warningMessage {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(warning)
                            .font(.caption)
                        Text("Available: \(DeviceCapability.availableMemoryFormatted)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: fit.canDownload
                          ? "exclamationmark.triangle"
                          : "xmark.octagon")
                        .foregroundStyle(fit.canDownload ? .orange : .red)
                }
            }
        }
    }
}
