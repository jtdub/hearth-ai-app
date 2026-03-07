import Foundation
import Testing
@testable import HearthAI

// MARK: - DownloadInfo

@Test @MainActor func downloadInfoInitialState() {
    let info = DownloadInfo(
        id: "user/repo/model.gguf",
        repoId: "user/repo",
        fileName: "model.gguf",
        fileSize: 500_000_000
    )
    #expect(info.progress == 0)
    #expect(info.resumeData == nil)
    #expect(info.task == nil)
    if case .queued = info.status {
        // expected
    } else {
        Issue.record("Expected .queued status")
    }
}

@Test @MainActor func downloadInfoProgressFormatZero() {
    let info = DownloadInfo(
        id: "test", repoId: "test",
        fileName: "model.gguf", fileSize: 1_000_000_000
    )
    info.progress = 0.0
    let formatted = info.formattedProgress
    #expect(formatted.contains("/"))
}

@Test @MainActor func downloadInfoProgressFormatHalf() {
    let info = DownloadInfo(
        id: "test", repoId: "test",
        fileName: "model.gguf", fileSize: 1_000_000_000
    )
    info.progress = 0.5
    let formatted = info.formattedProgress
    #expect(formatted.contains("/"))
}

@Test @MainActor func downloadInfoProgressFormatFull() {
    let info = DownloadInfo(
        id: "test", repoId: "test",
        fileName: "model.gguf", fileSize: 1_000_000_000
    )
    info.progress = 1.0
    let formatted = info.formattedProgress
    #expect(formatted.contains("/"))
}

// MARK: - DownloadService State

@Test @MainActor func downloadServiceInitialState() {
    let service = DownloadService()
    #expect(service.activeDownloads.isEmpty)
    #expect(service.hasActiveDownloads == false)
    #expect(service.downloads.isEmpty)
}

@Test @MainActor func cancelNonexistentDownloadIsNoOp() {
    let service = DownloadService()
    service.cancelDownload(id: "nonexistent")
    #expect(service.downloads.isEmpty)
}

@Test @MainActor func removeNonexistentDownloadIsNoOp() {
    let service = DownloadService()
    service.removeDownload(id: "nonexistent")
    #expect(service.downloads.isEmpty)
}

// MARK: - HFAPIError Descriptions

@Test func apiErrorInvalidURL() {
    let error = HFAPIError.invalidURL
    #expect(error.localizedDescription.contains("Invalid URL"))
}

@Test func apiErrorInvalidResponse() {
    let error = HFAPIError.invalidResponse
    #expect(error.localizedDescription.contains("Invalid response"))
}

@Test func apiErrorNotFound() {
    let error = HFAPIError.notFound
    #expect(error.localizedDescription.contains("not found"))
}

@Test func apiErrorRateLimited() {
    let error = HFAPIError.rateLimited
    #expect(error.localizedDescription.contains("Rate limited"))
}

@Test func apiErrorHTTPCode() {
    let error = HFAPIError.httpError(statusCode: 500)
    #expect(error.localizedDescription.contains("500"))
}

@Test func apiErrorHTTPCode403() {
    let error = HFAPIError.httpError(statusCode: 403)
    #expect(error.localizedDescription.contains("403"))
}

// MARK: - DownloadStatus

@Test @MainActor func downloadInfoStatusTransitions() {
    let info = DownloadInfo(
        id: "test", repoId: "test",
        fileName: "model.gguf", fileSize: 100
    )

    info.status = .downloading
    if case .downloading = info.status {} else {
        Issue.record("Expected .downloading")
    }

    info.status = .paused
    if case .paused = info.status {} else {
        Issue.record("Expected .paused")
    }

    info.status = .completed
    if case .completed = info.status {} else {
        Issue.record("Expected .completed")
    }

    info.status = .failed("Network error")
    if case .failed(let msg) = info.status {
        #expect(msg == "Network error")
    } else {
        Issue.record("Expected .failed")
    }
}
