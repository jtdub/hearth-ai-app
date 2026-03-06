import SwiftUI
import SwiftData

struct ModelDetailView: View {
    let model: HFModelInfo
    @Environment(DownloadService.self) private var downloadService
    @Query private var localModels: [LocalModel]
    @State private var files: [HFFileInfo] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let api = HuggingFaceAPI()

    var body: some View {
        List {
            Section("Model Info") {
                LabeledContent("Repository", value: model.id)
                LabeledContent("Family", value: model.modelFamily)
                LabeledContent("Downloads", value: "\(model.downloads)")
                LabeledContent("Likes", value: "\(model.likes)")
            }

            Section("Available Files") {
                if isLoading {
                    ProgressView("Loading files...")
                } else if let error = errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                } else if files.isEmpty {
                    Text("No GGUF files found")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(files) { file in
                        FileRow(
                            file: file,
                            repoId: model.id,
                            isDownloaded: isFileDownloaded(file),
                            activeDownload: downloadService.downloads[
                                "\(model.id)/\(file.fileName)"
                            ]
                        )
                    }
                }
            }
        }
        .navigationTitle(model.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadFiles()
        }
    }

    private func loadFiles() async {
        do {
            files = try await api.listFiles(repoId: model.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func isFileDownloaded(_ file: HFFileInfo) -> Bool {
        localModels.contains { $0.id == "\(model.id)/\(file.fileName)" }
    }
}

struct FileRow: View {
    let file: HFFileInfo
    let repoId: String
    let isDownloaded: Bool
    let activeDownload: DownloadInfo?
    @Environment(DownloadService.self) private var downloadService
    @Environment(NetworkMonitor.self) private var networkMonitor

    private static let cellularWarningThreshold: Int64 = 200_000_000

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(file.fileName)
                .font(.subheadline.bold())
                .lineLimit(1)
            HStack(spacing: 12) {
                Label(file.formattedSize, systemImage: "doc")
                Label(file.quantization, systemImage: "cpu")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            if isDownloaded {
                Label("Downloaded", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else if let download = activeDownload {
                DownloadProgressRow(download: download)
            } else {
                let fileSize = file.size ?? 0
                let fit = DeviceCapability.canRunModel(fileSizeBytes: fileSize)
                if let warning = fit.warningMessage {
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(fit.canDownload ? .orange : .red)
                }
                if fileSize > Self.cellularWarningThreshold && !networkMonitor.isOnWiFi {
                    Label(
                        "Large file — Wi-Fi recommended",
                        systemImage: "wifi.exclamationmark"
                    )
                    .font(.caption2)
                    .foregroundStyle(.orange)
                }
                Button {
                    downloadService.startDownload(
                        repoId: repoId,
                        fileName: file.fileName,
                        fileSize: file.size ?? 0
                    )
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                        .font(.caption)
                }
                .disabled(!fit.canDownload)
            }
        }
        .padding(.vertical, 4)
    }
}
