import Foundation
import SwiftData

@MainActor
@Observable
final class DownloadService: NSObject {
    private(set) var downloads: [String: DownloadInfo] = [:]
    var onDownloadComplete: (@MainActor (DownloadInfo) -> Void)?

    private let api = HuggingFaceAPI()
    private nonisolated(unsafe) var backgroundSession: URLSession!
    private let delegateQueue = OperationQueue()
    private let taskMapLock = NSLock()
    private nonisolated(unsafe) var taskToDownloadId: [Int: String] = [:]

    override init() {
        super.init()
        delegateQueue.maxConcurrentOperationCount = 1
        let config = URLSessionConfiguration.background(
            withIdentifier: "ai.hearth.download"
        )
        config.isDiscretionary = false
        #if os(iOS) || os(visionOS)
        config.sessionSendsLaunchEvents = true
        #endif
        backgroundSession = URLSession(
            configuration: config,
            delegate: self,
            delegateQueue: delegateQueue
        )
    }

    private func setTaskMapping(_ taskId: Int, downloadId: String) {
        taskMapLock.lock()
        defer { taskMapLock.unlock() }
        taskToDownloadId[taskId] = downloadId
    }

    private nonisolated func getTaskMapping(_ taskId: Int) -> String? {
        taskMapLock.lock()
        defer { taskMapLock.unlock() }
        return taskToDownloadId[taskId]
    }

    private nonisolated func removeTaskMapping(_ taskId: Int) {
        taskMapLock.lock()
        defer { taskMapLock.unlock() }
        taskToDownloadId.removeValue(forKey: taskId)
    }

    var activeDownloads: [DownloadInfo] {
        Array(downloads.values).sorted { $0.id < $1.id }
    }

    var hasActiveDownloads: Bool {
        downloads.values.contains {
            if case .downloading = $0.status { return true }
            if case .queued = $0.status { return true }
            return false
        }
    }

    // MARK: - Download Control

    func startDownload(repoId: String, fileName: String, fileSize: Int64) {
        let downloadId = "\(repoId)/\(fileName)"
        guard downloads[downloadId] == nil else { return }

        let info = DownloadInfo(
            id: downloadId,
            repoId: repoId,
            fileName: fileName,
            fileSize: fileSize
        )

        let url = api.downloadURL(repoId: repoId, fileName: fileName)
        let task = backgroundSession.downloadTask(with: url)

        info.task = task
        info.status = .downloading
        downloads[downloadId] = info
        setTaskMapping(task.taskIdentifier, downloadId: downloadId)

        task.resume()
    }

    func pauseDownload(id: String) {
        guard let info = downloads[id], let task = info.task else { return }
        info.status = .paused
        task.cancel { [weak self] data in
            Task { @MainActor in
                guard let self else { return }
                if case .paused = self.downloads[id]?.status {
                    self.downloads[id]?.resumeData = data
                }
            }
        }
    }

    func resumeDownload(id: String) {
        guard let info = downloads[id] else { return }

        let task: URLSessionDownloadTask
        if let resumeData = info.resumeData {
            task = backgroundSession.downloadTask(withResumeData: resumeData)
        } else {
            let url = api.downloadURL(repoId: info.repoId, fileName: info.fileName)
            task = backgroundSession.downloadTask(with: url)
        }

        info.task = task
        info.status = .downloading
        info.resumeData = nil
        setTaskMapping(task.taskIdentifier, downloadId: id)

        task.resume()
    }

    func cancelDownload(id: String) {
        guard let info = downloads[id] else { return }
        info.task?.cancel()
        downloads.removeValue(forKey: id)
    }

    func removeDownload(id: String) {
        downloads.removeValue(forKey: id)
    }

}

// MARK: - URLSessionDownloadDelegate

extension DownloadService: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let downloadId = getTaskMapping(downloadTask.taskIdentifier) else { return }

        let result: Result<String, Error>
        do {
            // Must move file synchronously before this method returns
            // downloadId format is "owner/repo/fileName"
            let parts = downloadId.components(separatedBy: "/")
            let fileName = parts.last ?? ""
            let repoId = parts.dropLast().joined(separator: "/")
            let repoComponent = repoId.replacingOccurrences(of: "/", with: "_")
            guard let appSupportDir = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first else {
                throw URLError(.cannotCreateFile)
            }
            let modelsDir = appSupportDir.appendingPathComponent("Models", isDirectory: true)
            let repoDir = modelsDir.appendingPathComponent(repoComponent, isDirectory: true)
            try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
            let destURL = repoDir.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.moveItem(at: location, to: destURL)
            result = .success("\(repoComponent)/\(fileName)")
        } catch {
            result = .failure(error)
        }

        removeTaskMapping(downloadTask.taskIdentifier)

        Task { @MainActor [weak self] in
            guard let self, let info = self.downloads[downloadId] else { return }
            switch result {
            case .success:
                info.status = .completed
                info.progress = 1.0
                self.onDownloadComplete?(info)
            case .failure(let error):
                info.status = .failed(error.localizedDescription)
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let downloadId = getTaskMapping(downloadTask.taskIdentifier) else { return }

        let totalWritten = totalBytesWritten
        let expectedTotal = totalBytesExpectedToWrite

        Task { @MainActor [weak self] in
            guard let self, let info = self.downloads[downloadId] else { return }
            let total = expectedTotal > 0 ? expectedTotal : info.fileSize
            let progress = total > 0 ? Double(totalWritten) / Double(total) : 0
            info.progress = progress
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        guard let error else { return }
        let nsError = error as NSError
        if nsError.code == NSURLErrorCancelled { return }

        guard let downloadId = getTaskMapping(task.taskIdentifier) else { return }
        removeTaskMapping(task.taskIdentifier)
        let errorMessage = error.localizedDescription

        Task { @MainActor [weak self] in
            guard let self, let info = self.downloads[downloadId] else { return }
            info.status = .failed(errorMessage)
        }
    }
}
