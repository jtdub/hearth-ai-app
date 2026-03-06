import Foundation
import SwiftData

@Model
final class LocalModel {
    @Attribute(.unique) var id: String
    var repoId: String
    var fileName: String
    var displayName: String
    var modelFamily: String
    var quantization: String
    var fileSizeBytes: Int64
    var downloadedAt: Date
    var lastUsedAt: Date?
    var localPath: String

    init(
        id: String,
        repoId: String,
        fileName: String,
        displayName: String,
        modelFamily: String,
        quantization: String,
        fileSizeBytes: Int64,
        downloadedAt: Date = .now,
        localPath: String
    ) {
        self.id = id
        self.repoId = repoId
        self.fileName = fileName
        self.displayName = displayName
        self.modelFamily = modelFamily
        self.quantization = quantization
        self.fileSizeBytes = fileSizeBytes
        self.downloadedAt = downloadedAt
        self.localPath = localPath
    }

    var absolutePath: URL {
        FileManager.modelsDirectory.appendingPathComponent(localPath)
    }
}
