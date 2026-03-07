import Foundation

struct CompatibleFile: Identifiable {
    let repoId: String
    let repoName: String
    let file: HFFileInfo
    let fit: ModelFitResult
    let downloads: Int

    var id: String { "\(repoId)/\(file.fileName)" }
}

@MainActor
@Observable
final class ModelStoreViewModel {
    var searchText = ""
    var searchResults: [HFModelInfo] = []
    var isSearching = false
    var errorMessage: String?
    var featuredModels: [FeaturedModel] = []

    // Compatible models discovered from HF
    var compatibleFiles: [CompatibleFile] = []
    var isLoadingCompatible = false
    var compatibleError: String?

    // Tracks file listings per repo
    var repoFiles: [String: [HFFileInfo]] = [:]
    var isLoadingFiles: [String: Bool] = [:]

    private let api = HuggingFaceAPI()
    private var searchTask: Task<Void, Never>?

    init() {
        featuredModels = FeaturedModel.loadFeatured()
    }

    func search() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        searchTask?.cancel()
        searchTask = Task {
            isSearching = true
            errorMessage = nil

            do {
                let results = try await api.searchModels(query: query)
                if !Task.isCancelled {
                    searchResults = results
                }
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                }
            }

            if !Task.isCancelled {
                isSearching = false
            }
        }
    }

    func loadCompatibleModels() {
        guard compatibleFiles.isEmpty, !isLoadingCompatible else { return }
        isLoadingCompatible = true
        compatibleError = nil

        Task {
            do {
                let allFiles = try await fetchCompatibleFiles()
                if !Task.isCancelled {
                    compatibleFiles = allFiles.sorted { lhs, rhs in
                        if lhs.fit == .fits && rhs.fit != .fits { return true }
                        if lhs.fit != .fits && rhs.fit == .fits { return false }
                        return lhs.downloads > rhs.downloads
                    }
                }
            } catch {
                if !Task.isCancelled {
                    compatibleError = error.localizedDescription
                }
            }
            if !Task.isCancelled {
                isLoadingCompatible = false
            }
        }
    }

    private func fetchCompatibleFiles() async throws -> [CompatibleFile] {
        let queries = ["gguf instruct small", "gguf chat 1b", "gguf chat 3b"]
        var allFiles: [CompatibleFile] = []
        var seenIds = Set<String>()

        for query in queries {
            guard !Task.isCancelled else { break }
            let models = try await api.searchModels(query: query, limit: 10)
            let files = await collectFiles(
                from: models, seen: &seenIds
            )
            allFiles.append(contentsOf: files)
        }
        return allFiles
    }

    private func collectFiles(
        from models: [HFModelInfo],
        seen: inout Set<String>
    ) async -> [CompatibleFile] {
        var result: [CompatibleFile] = []
        for model in models.prefix(5) {
            guard !Task.isCancelled else { break }
            guard let files = try? await api.listFiles(repoId: model.id) else {
                continue
            }
            for file in files where file.isGGUF {
                let fileId = "\(model.id)/\(file.fileName)"
                guard !seen.contains(fileId) else { continue }
                seen.insert(fileId)

                let size = file.size ?? 0
                let fit = DeviceCapability.canRunModel(fileSizeBytes: size)
                if fit.canDownload && size > 0 {
                    result.append(CompatibleFile(
                        repoId: model.id,
                        repoName: model.displayName,
                        file: file,
                        fit: fit,
                        downloads: model.downloads
                    ))
                }
            }
        }
        return result
    }

    func loadFiles(for repoId: String) async {
        guard repoFiles[repoId] == nil else { return }
        isLoadingFiles[repoId] = true

        do {
            let files = try await api.listFiles(repoId: repoId)
            repoFiles[repoId] = files
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingFiles[repoId] = false
    }

    func retry() {
        errorMessage = nil
        search()
    }

    func clearSearch() {
        searchText = ""
        searchResults = []
        errorMessage = nil
    }
}
