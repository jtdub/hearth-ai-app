import Foundation

enum DeviceCapability {
    static var availableMemoryBytes: Int64 {
        let available = Int64(os_proc_available_memory())
        // os_proc_available_memory() returns 0 on the simulator
        if available <= 0 {
            return totalMemoryBytes
        }
        return available
    }

    static var totalMemoryBytes: Int64 {
        Int64(ProcessInfo.processInfo.physicalMemory)
    }

    static let memoryOverheadBytes: Int64 = 2_000_000_000 // 2 GB

    static func canRunModel(fileSizeBytes: Int64) -> ModelFitResult {
        let required = fileSizeBytes + memoryOverheadBytes
        let available = availableMemoryBytes

        if available >= required {
            return .fits
        } else if available >= fileSizeBytes {
            return .tight
        } else {
            return .tooLarge
        }
    }

    static var availableMemoryFormatted: String {
        ByteCountFormatter.string(fromByteCount: availableMemoryBytes, countStyle: .memory)
    }
}

enum ModelFitResult {
    case fits
    case tight
    case tooLarge

    var warningMessage: String? {
        switch self {
        case .fits:
            nil
        case .tight:
            "This model may strain your device's memory. Performance could be affected."
        case .tooLarge:
            "This model is likely too large for your device's available memory."
        }
    }

    var canDownload: Bool {
        self != .tooLarge
    }
}
