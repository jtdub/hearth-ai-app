import Foundation

extension FileManager {
    static var appSupportDirectory: URL {
        guard let url = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else {
            fatalError("Application Support directory is unavailable")
        }
        return url
    }

    static var modelsDirectory: URL {
        let dir = appSupportDirectory.appendingPathComponent("Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var availableDiskSpace: Int64 {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? homeURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let capacity = values.volumeAvailableCapacityForImportantUsage else {
            return 0
        }
        return capacity
    }
}
