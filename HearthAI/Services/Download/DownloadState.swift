import Foundation

enum DownloadStatus: Sendable {
    case queued
    case downloading
    case paused
    case completed
    case failed(String)
}

@Observable
final class DownloadInfo: Identifiable {
    let id: String
    let repoId: String
    let fileName: String
    let fileSize: Int64
    var progress: Double = 0
    var status: DownloadStatus = .queued
    var resumeData: Data?
    var task: URLSessionDownloadTask?

    init(id: String, repoId: String, fileName: String, fileSize: Int64) {
        self.id = id
        self.repoId = repoId
        self.fileName = fileName
        self.fileSize = fileSize
    }

    var formattedProgress: String {
        let downloaded = Int64(Double(fileSize) * progress)
        let total = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
        let done = ByteCountFormatter.string(fromByteCount: downloaded, countStyle: .file)
        return "\(done) / \(total)"
    }
}
