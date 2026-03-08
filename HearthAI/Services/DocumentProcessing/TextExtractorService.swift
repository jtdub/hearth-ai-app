import Foundation
import PDFKit
#if canImport(Vision)
import Vision
#endif

struct ExtractedText {
    let text: String
    let pageCount: Int32?
}

enum TextExtractorService {

    static func extractText(
        from url: URL,
        type: DocumentSourceType
    ) async throws -> ExtractedText {
        switch type {
        case .pdf:
            return try extractFromPDF(url: url)
        case .txt:
            return try extractFromText(url: url)
        case .image:
            return try await extractFromImage(url: url)
        }
    }

    // MARK: - PDF

    private static func extractFromPDF(
        url: URL
    ) throws -> ExtractedText {
        guard let document = PDFDocument(url: url) else {
            throw DocumentError.unableToReadFile(url.lastPathComponent)
        }

        var text = ""
        let pageCount = document.pageCount

        for index in 0..<pageCount {
            if let page = document.page(at: index),
               let pageText = page.string {
                if !text.isEmpty { text += "\n\n" }
                text += pageText
            }
        }

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty else {
            throw DocumentError.noTextContent(url.lastPathComponent)
        }

        return ExtractedText(
            text: text, pageCount: Int32(pageCount)
        )
    }

    // MARK: - Plain Text

    private static func extractFromText(
        url: URL
    ) throws -> ExtractedText {
        let text = try String(contentsOf: url, encoding: .utf8)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty else {
            throw DocumentError.noTextContent(url.lastPathComponent)
        }
        return ExtractedText(text: text, pageCount: nil)
    }

    // MARK: - Image (OCR)

    private static func extractFromImage(
        url: URL
    ) async throws -> ExtractedText {
        #if canImport(Vision)
        let data = try Data(contentsOf: url)

        #if os(macOS)
        guard let nsImage = NSImage(data: data),
              let cgImage = nsImage.cgImage(
                forProposedRect: nil, context: nil, hints: nil
              ) else {
            throw DocumentError.unableToReadFile(url.lastPathComponent)
        }
        #else
        guard let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage else {
            throw DocumentError.unableToReadFile(url.lastPathComponent)
        }
        #endif

        let text = try await performOCR(on: cgImage)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty else {
            throw DocumentError.noTextContent(url.lastPathComponent)
        }
        return ExtractedText(text: text, pageCount: nil)
        #else
        throw DocumentError.ocrUnavailable
        #endif
    }

    #if canImport(Vision)
    private static func performOCR(
        on image: CGImage
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results
                    as? [VNRecognizedTextObservation] ?? []
                let text = observations.compactMap {
                    $0.topCandidates(1).first?.string
                }.joined(separator: "\n")

                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(
                cgImage: image, options: [:]
            )

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    #endif
}

enum DocumentError: Error, LocalizedError {
    case unableToReadFile(String)
    case noTextContent(String)
    case ocrUnavailable
    case unsupportedFormat(String)

    var errorDescription: String? {
        switch self {
        case .unableToReadFile(let name):
            "Unable to read file: \(name)"
        case .noTextContent(let name):
            "No text content found in: \(name)"
        case .ocrUnavailable:
            "OCR is not available on this platform."
        case .unsupportedFormat(let ext):
            "Unsupported file format: \(ext)"
        }
    }
}
