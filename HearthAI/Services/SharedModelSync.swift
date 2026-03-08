import Foundation
import SwiftData

/// Syncs available model info to the App Group shared container
/// so extensions can enumerate downloaded models.
@MainActor
final class SharedModelSync {

    func syncModels(context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<LocalModel>()
            let models = try context.fetch(descriptor)
            let sharedModels = models.map { model in
                SharedModelInfo(
                    id: model.id,
                    displayName: model.displayName,
                    modelFamily: model.modelFamily,
                    quantization: model.quantization,
                    fileSizeBytes: model.fileSizeBytes,
                    localPath: model.localPath
                )
            }

            guard let url = AppGroupConstants.availableModelsURL else { return }
            let data = try JSONEncoder().encode(sharedModels)
            try data.write(to: url)
        } catch {
            // Non-fatal: extensions just won't see updated model list
        }
    }

    static func loadAvailableModels() -> [SharedModelInfo] {
        SharedModelInfo.loadFromSharedContainer()
    }
}
