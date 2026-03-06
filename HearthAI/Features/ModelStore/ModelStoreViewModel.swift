import Foundation

@Observable
final class ModelStoreViewModel {
    var searchText = ""
    var searchResults: [HFModelInfo] = []
    var isSearching = false
    var errorMessage: String?
    var featuredModels: [FeaturedModel] = []

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
