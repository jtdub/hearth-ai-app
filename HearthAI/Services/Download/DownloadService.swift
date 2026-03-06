import Foundation
import SwiftData

@Observable
final class DownloadService: NSObject {
    private(set) var downloads: [String: DownloadInfo] = [:]
    var onDownloadComplete: ((DownloadInfo) -> Void)?

    private let api = HuggingFaceAPI()
    private var backgroundSession: URLSession!
    private var taskToDownloadId: [Int: String] = [:]

    override init() {
        super.init()
        let config = URLSessionConfiguration.background(
            withIdentifier: "ai.hearth.download"
        )
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        backgroundSession = URLSession(
            configuration: config,
            delegate: self,
            delegateQueue: nil
        )
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
        taskToDownloadId[task.taskIdentifier] = downloadId

        task.resume()
    }

    func pauseDownload(id: String) {
        guard let info = downloads[id], let task = info.task else { return }
        task.cancel { [weak self] data in
            DispatchQueue.main.async {
                self?.downloads[id]?.resumeData = data
                self?.downloads[id]?.status = .paused
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
        taskToDownloadId[task.taskIdentifier] = id

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

    // MARK: - File Management

    private func moveDownloadedFile(from tempURL: URL, downloadInfo: DownloadInfo) throws -> String {
        let modelsDir = FileManager.modelsDirectory
        let repoDir = modelsDir.appendingPathComponent(
            downloadInfo.repoId.replacingOccurrences(of: "/", with: "_"),
            isDirectory: true
        )

        try FileManager.default.createDirectory(
            at: repoDir,
            withIntermediateDirectories: true
        )

        let destURL = repoDir.appendingPathComponent(downloadInfo.fileName)

        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }

        try FileManager.default.moveItem(at: tempURL, to: destURL)

        let repoComponent = downloadInfo.repoId.replacingOccurrences(of: "/", with: "_")
        return "\(repoComponent)/\(downloadInfo.fileName)"
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadService: URLSessionDownloadDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let downloadId = taskToDownloadId[downloadTask.taskIdentifier],
              let info = downloads[downloadId] else { return }

        do {
            let localPath = try moveDownloadedFile(from: location, downloadInfo: info)
            let destURL = FileManager.modelsDirectory.appendingPathComponent(localPath)
            let actualSize = (try? FileManager.default.attributesOfItem(
                atPath: destURL.path
            )[.size] as? Int64) ?? info.fileSize
            DispatchQueue.main.async {
                info.actualFileSize = actualSize
                info.status = .completed
                info.progress = 1.0
                self.onDownloadComplete?(info)
            }
        } catch {
            DispatchQueue.main.async {
                info.status = .failed(error.localizedDescription)
            }
        }

        taskToDownloadId.removeValue(forKey: downloadTask.taskIdentifier)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let downloadId = taskToDownloadId[downloadTask.taskIdentifier],
              let info = downloads[downloadId] else { return }

        let total = totalBytesExpectedToWrite > 0
            ? totalBytesExpectedToWrite
            : info.fileSize
        let progress = total > 0 ? Double(totalBytesWritten) / Double(total) : 0

        DispatchQueue.main.async {
            info.progress = progress
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        guard let error,
              let downloadId = taskToDownloadId[task.taskIdentifier],
              let info = downloads[downloadId] else { return }

        let nsError = error as NSError
        if nsError.code == NSURLErrorCancelled {
            return
        }

        DispatchQueue.main.async {
            info.status = .failed(error.localizedDescription)
        }
        taskToDownloadId.removeValue(forKey: task.taskIdentifier)
    }
}
