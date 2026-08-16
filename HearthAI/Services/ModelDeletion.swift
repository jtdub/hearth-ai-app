import Foundation
import SwiftData

/// Removes a downloaded model from the device: unloads it if
/// it is active, deletes the file, and deletes the record.
@MainActor
enum ModelDeletion {
    static func delete(
        _ model: LocalModel,
        context: ModelContext,
        inferenceService: InferenceService
    ) async {
        if inferenceService.loadedModelId == model.id {
            await inferenceService.unloadModel()
        }
        try? FileManager.default.removeItem(at: model.absolutePath)
        context.delete(model)
        try? context.save()
    }
}
