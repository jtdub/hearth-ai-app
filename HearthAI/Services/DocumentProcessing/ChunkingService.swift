import Foundation

enum ChunkingService {

    /// Splits text into chunks of approximately `maxTokens` size
    /// with `overlapTokens` overlap between consecutive chunks.
    /// Token count is estimated as character count / 4.
    static func chunk(
        text: String,
        maxTokens: Int = Constants.defaultChunkSize,
        overlapTokens: Int = Constants.defaultChunkOverlap
    ) -> [String] {
        let trimmed = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else { return [] }

        let maxChars = maxTokens * 4
        let overlapChars = overlapTokens * 4

        // If text fits in a single chunk, return it directly
        if trimmed.count <= maxChars {
            return [trimmed]
        }

        let paragraphs = splitIntoParagraphs(trimmed)
        var chunks: [String] = []
        var currentChunk = ""

        for paragraph in paragraphs {
            let candidate = currentChunk.isEmpty
                ? paragraph
                : currentChunk + "\n\n" + paragraph

            if candidate.count <= maxChars {
                currentChunk = candidate
            } else {
                // If current chunk has content, save it
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk)
                    // Start next chunk with overlap from end
                    currentChunk = overlap(
                        from: currentChunk,
                        chars: overlapChars
                    ) + "\n\n" + paragraph
                } else {
                    // Single paragraph exceeds max — split by sentences
                    let sentenceChunks = splitBySentences(
                        paragraph, maxChars: maxChars,
                        overlapChars: overlapChars
                    )
                    chunks.append(contentsOf: sentenceChunks.dropLast())
                    currentChunk = sentenceChunks.last ?? ""
                }
            }
        }

        if !currentChunk.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty {
            chunks.append(currentChunk)
        }

        return chunks
    }

    // MARK: - Private

    private static func splitIntoParagraphs(
        _ text: String
    ) -> [String] {
        text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func overlap(
        from text: String, chars: Int
    ) -> String {
        guard chars > 0, text.count > chars else { return text }
        let start = text.index(text.endIndex, offsetBy: -chars)
        return String(text[start...])
    }

    private static func splitBySentences(
        _ text: String,
        maxChars: Int,
        overlapChars: Int
    ) -> [String] {
        let sentences = text.components(separatedBy: ". ")
            .map { $0.hasSuffix(".") ? $0 : $0 + "." }

        var chunks: [String] = []
        var current = ""

        for sentence in sentences {
            let candidate = current.isEmpty
                ? sentence
                : current + " " + sentence

            if candidate.count <= maxChars {
                current = candidate
            } else {
                if !current.isEmpty {
                    chunks.append(current)
                    current = overlap(
                        from: current, chars: overlapChars
                    ) + " " + sentence
                } else {
                    // Single sentence exceeds max — just truncate
                    chunks.append(
                        String(sentence.prefix(maxChars))
                    )
                    current = ""
                }
            }
        }

        if !current.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty {
            chunks.append(current)
        }

        return chunks
    }
}
