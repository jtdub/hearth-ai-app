import Foundation

enum AppGroupConstants {
    static let groupId = "group.ai.hearth.shared"
    static let urlScheme = "hearth"

    static var sharedContainerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupId
        )
    }

    static var pendingRequestsDirectory: URL? {
        guard let container = sharedContainerURL else { return nil }
        let dir = container.appendingPathComponent(
            "PendingRequests", isDirectory: true
        )
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
        return dir
    }

    static var availableModelsURL: URL? {
        sharedContainerURL?.appendingPathComponent("available_models.json")
    }
}
