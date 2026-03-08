import Foundation
import SwiftUI
import SwiftData
#if os(iOS) || os(visionOS)
import PhotosUI
#endif

@MainActor
@Observable
final class DocumentImportViewModel {
    var isImporting = false
    var importError: String?

    func importFile(
        from url: URL, context: ModelContext
    ) async {
        isImporting = true
        importError = nil

        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            let sourceType = detectSourceType(url: url)
            let result = try await TextExtractorService.extractText(
                from: url, type: sourceType
            )

            let attrs = try? FileManager.default.attributesOfItem(
                atPath: url.path
            )
            let fileSize = attrs?[.size] as? Int64 ?? 0

            let document = Document(
                title: url.deletingPathExtension().lastPathComponent,
                sourceType: sourceType,
                rawText: result.text,
                fileSize: fileSize,
                pageCount: result.pageCount
            )
            context.insert(document)

            let chunkTexts = ChunkingService.chunk(text: result.text)
            for (index, text) in chunkTexts.enumerated() {
                let chunk = DocumentChunk(
                    content: text, chunkIndex: Int32(index)
                )
                chunk.document = document
                document.chunks.append(chunk)
            }

            try context.save()
        } catch {
            importError = error.localizedDescription
        }

        isImporting = false
    }

    #if os(iOS) || os(visionOS)
    func importPhoto(
        from item: PhotosPickerItem, context: ModelContext
    ) async {
        isImporting = true
        importError = nil

        do {
            guard let data = try await item.loadTransferable(
                type: Data.self
            ) else {
                importError = "Unable to load photo."
                isImporting = false
                return
            }

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".jpg")
            try data.write(to: tempURL)
            defer { try? FileManager.default.removeItem(at: tempURL) }

            let result = try await TextExtractorService.extractText(
                from: tempURL, type: .image
            )

            let document = Document(
                title: "Scanned Document",
                sourceType: .image,
                rawText: result.text,
                fileSize: Int64(data.count)
            )
            context.insert(document)

            let chunkTexts = ChunkingService.chunk(text: result.text)
            for (index, text) in chunkTexts.enumerated() {
                let chunk = DocumentChunk(
                    content: text, chunkIndex: Int32(index)
                )
                chunk.document = document
                document.chunks.append(chunk)
            }

            try context.save()
        } catch {
            importError = error.localizedDescription
        }

        isImporting = false
    }
    #endif

    private func detectSourceType(url: URL) -> DocumentSourceType {
        switch url.pathExtension.lowercased() {
        case "pdf": .pdf
        case "png", "jpg", "jpeg", "heic", "heif", "tiff": .image
        default: .txt
        }
    }
}
