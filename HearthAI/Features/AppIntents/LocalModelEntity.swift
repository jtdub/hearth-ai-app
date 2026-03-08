import AppIntents
import Foundation

struct LocalModelEntity: AppEntity {
    static var defaultQuery = LocalModelEntityQuery()
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "AI Model"
    }

    var id: String
    var displayName: String
    var modelFamily: String
    var quantization: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(displayName)",
            subtitle: "\(modelFamily) • \(quantization)"
        )
    }
}

struct LocalModelEntityQuery: EntityQuery {
    func entities(
        for identifiers: [LocalModelEntity.ID]
    ) async throws -> [LocalModelEntity] {
        let models = SharedModelInfo.loadFromSharedContainer()
        return models
            .filter { identifiers.contains($0.id) }
            .map { model in
                LocalModelEntity(
                    id: model.id,
                    displayName: model.displayName,
                    modelFamily: model.modelFamily,
                    quantization: model.quantization
                )
            }
    }

    func suggestedEntities() async throws -> [LocalModelEntity] {
        SharedModelInfo.loadFromSharedContainer().map { model in
            LocalModelEntity(
                id: model.id,
                displayName: model.displayName,
                modelFamily: model.modelFamily,
                quantization: model.quantization
            )
        }
    }
}
