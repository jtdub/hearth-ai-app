import Foundation
import Testing
@testable import HearthAI

@Test func fitsResultProperties() {
    let result = ModelFitResult.fits
    #expect(result.canDownload == true)
    #expect(result.warningMessage == nil)
}

@Test func tightResultProperties() {
    let result = ModelFitResult.tight
    #expect(result.canDownload == true)
    #expect(result.warningMessage != nil)
    #expect(result.warningMessage?.contains("strain") == true)
}

@Test func tooLargeResultProperties() {
    let result = ModelFitResult.tooLarge
    #expect(result.canDownload == false)
    #expect(result.warningMessage != nil)
    #expect(result.warningMessage?.contains("too large") == true)
}

@Test func zeroSizeModelFits() {
    let result = DeviceCapability.canRunModel(fileSizeBytes: 0)
    #expect(result == .fits)
}

@Test func negativeSizeModelFits() {
    let result = DeviceCapability.canRunModel(fileSizeBytes: -100)
    #expect(result == .fits)
}

@Test func smallModelFits() {
    // 1 MB should always fit on any modern device
    let result = DeviceCapability.canRunModel(fileSizeBytes: 1_000_000)
    #expect(result == .fits)
}

@Test func enormousModelTooLarge() {
    // 999 TB should never fit
    let result = DeviceCapability.canRunModel(
        fileSizeBytes: 999_000_000_000_000
    )
    #expect(result == .tooLarge)
}

@Test func memoryOverheadIsReasonable() {
    // Overhead should be a positive value (currently 2 GB)
    #expect(DeviceCapability.memoryOverheadBytes > 0)
    // And not absurdly large (< 10 GB)
    #expect(DeviceCapability.memoryOverheadBytes < 10_000_000_000)
}

@Test func availableMemoryIsPositive() {
    #expect(DeviceCapability.availableMemoryBytes > 0)
}

@Test func totalMemoryIsPositive() {
    #expect(DeviceCapability.totalMemoryBytes > 0)
}

@Test func availableMemoryFormattedNotEmpty() {
    let formatted = DeviceCapability.availableMemoryFormatted
    #expect(!formatted.isEmpty)
}
