import Foundation
import SwiftData

/// Removes a downloaded model from the device: unloads it if
/// it is active, clears its download entry, deletes the file
/// and the record, and updates the shared model list.
@MainActor
enum ModelDeletion {
    static func delete(
        _ model: LocalModel,
        context: ModelContext,
        inferenceService: InferenceService,
        downloadService: DownloadService
    ) async {
        if inferenceService.loadedModelId == model.id {
            await inferenceService.unloadModel()
        }
        downloadService.removeDownload(
            id: "\(model.repoId)/\(model.fileName)"
        )
        try? FileManager.default.removeItem(at: model.absolutePath)
        context.delete(model)
        try? context.save()
        SharedModelSync().syncModels(context: context)
    }
}
