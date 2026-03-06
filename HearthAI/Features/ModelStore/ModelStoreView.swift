import SwiftUI
import SwiftData

struct ModelStoreView: View {
    @Environment(DownloadService.self) private var downloadService
    @Query private var localModels: [LocalModel]
    @State private var viewModel = ModelStoreViewModel()

    var body: some View {
        NavigationStack {
            List {
                if !downloadService.activeDownloads.isEmpty {
                    activeDownloadsSection
                }

                if viewModel.searchText.isEmpty {
                    featuredSection
                } else if viewModel.isSearching {
                    Section {
                        ProgressView("Searching...")
                            .frame(maxWidth: .infinity)
                    }
                } else if let error = viewModel.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                        Button("Retry") {
                            viewModel.retry()
                        }
                    }
                } else {
                    searchResultsSection
                }
            }
            .navigationTitle("Models")
            .searchable(text: $viewModel.searchText, prompt: "Search GGUF models...")
            .onSubmit(of: .search) {
                viewModel.search()
            }
            .onChange(of: viewModel.searchText) {
                if viewModel.searchText.isEmpty {
                    viewModel.clearSearch()
                }
            }
        }
    }

    // MARK: - Active Downloads

    private var activeDownloadsSection: some View {
        Section("Downloads") {
            ForEach(downloadService.activeDownloads) { download in
                DownloadProgressRow(download: download)
            }
        }
    }

    // MARK: - Featured Models

    private var featuredSection: some View {
        Section("Recommended Models") {
            ForEach(viewModel.featuredModels) { model in
                NavigationLink {
                    FeaturedModelDetailView(model: model)
                } label: {
                    FeaturedModelRow(
                        model: model,
                        isDownloaded: isModelDownloaded(model.id)
                    )
                }
            }
        }
    }

    // MARK: - Search Results

    private var searchResultsSection: some View {
        Section("Results (\(viewModel.searchResults.count))") {
            ForEach(viewModel.searchResults) { model in
                NavigationLink {
                    ModelDetailView(model: model)
                } label: {
                    SearchResultRow(model: model)
                }
            }

            if viewModel.searchResults.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different search term.")
                )
            }
        }
    }

    private func isModelDownloaded(_ modelId: String) -> Bool {
        localModels.contains { $0.id == modelId }
    }
}

// MARK: - Row Views

struct FeaturedModelRow: View {
    let model: FeaturedModel
    let isDownloaded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(model.displayName)
                    .font(.headline)
                if isDownloaded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }
            Text(model.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack(spacing: 12) {
                Label(model.formattedSize, systemImage: "doc")
                Label(model.quantization, systemImage: "cpu")
                Label(model.modelFamily, systemImage: "brain")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct SearchResultRow: View {
    let model: HFModelInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.displayName)
                .font(.headline)
            Text(model.id)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Label("\(model.downloads)", systemImage: "arrow.down.circle")
                Label("\(model.likes)", systemImage: "heart")
                Label(model.modelFamily, systemImage: "brain")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct DownloadProgressRow: View {
    @Bindable var download: DownloadInfo
    @Environment(DownloadService.self) private var downloadService

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(download.fileName)
                .font(.subheadline.bold())
                .lineLimit(1)

            switch download.status {
            case .queued:
                Text("Queued...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .downloading:
                ProgressView(value: download.progress)
                HStack {
                    Text(download.formattedProgress)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Pause") {
                        downloadService.pauseDownload(id: download.id)
                    }
                    .font(.caption)
                    Button("Cancel", role: .destructive) {
                        downloadService.cancelDownload(id: download.id)
                    }
                    .font(.caption)
                }
            case .paused:
                ProgressView(value: download.progress)
                    .tint(.orange)
                HStack {
                    Text("Paused")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("Resume") {
                        downloadService.resumeDownload(id: download.id)
                    }
                    .font(.caption)
                    Button("Cancel", role: .destructive) {
                        downloadService.cancelDownload(id: download.id)
                    }
                    .font(.caption)
                }
            case .completed:
                Label("Download complete", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            case .failed(let error):
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ModelStoreView()
        .environment(DownloadService())
        .modelContainer(for: LocalModel.self, inMemory: true)
}
