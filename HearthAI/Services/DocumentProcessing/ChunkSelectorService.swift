import Foundation

enum ChunkSelectorService {

    /// Selects the most relevant chunks for a query using TF-IDF
    /// scoring. Returns chunks sorted by relevance, up to
    /// `maxTokenBudget` total estimated tokens.
    static func selectChunks(
        query: String,
        chunks: [DocumentChunk],
        maxTokenBudget: Int
    ) -> [DocumentChunk] {
        guard !chunks.isEmpty, !query.isEmpty else { return [] }

        let queryTerms = tokenize(query)
        guard !queryTerms.isEmpty else {
            // No meaningful terms — return first chunks up to budget
            return takeWithinBudget(
                chunks.sorted { $0.chunkIndex < $1.chunkIndex },
                budget: maxTokenBudget
            )
        }

        // Compute IDF for each query term across all chunks
        let totalDocs = Double(chunks.count)
        var idf: [String: Double] = [:]
        for term in queryTerms {
            let docsWithTerm = chunks.filter {
                tokenize($0.content).contains(term)
            }.count
            idf[term] = log(
                (totalDocs + 1) / (Double(docsWithTerm) + 1)
            ) + 1
        }

        // Score each chunk
        let scored: [(chunk: DocumentChunk, score: Double)] = chunks
            .map { chunk in
                let chunkTokens = tokenize(chunk.content)
                let totalTokens = Double(chunkTokens.count)
                guard totalTokens > 0 else {
                    return (chunk: chunk, score: 0)
                }

                var score = 0.0
                for term in queryTerms {
                    let termFreq = Double(
                        chunkTokens.filter { $0 == term }.count
                    ) / totalTokens
                    score += termFreq * (idf[term] ?? 1.0)
                }
                return (chunk: chunk, score: score)
            }
            .sorted { $0.score > $1.score }

        return takeWithinBudget(
            scored.map(\.chunk), budget: maxTokenBudget
        )
    }

    // MARK: - Private

    private static func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count > 2 }
    }

    private static func takeWithinBudget(
        _ chunks: [DocumentChunk], budget: Int
    ) -> [DocumentChunk] {
        var result: [DocumentChunk] = []
        var remaining = budget
        for chunk in chunks {
            let tokens = Int(chunk.tokenEstimate)
            if tokens <= remaining {
                result.append(chunk)
                remaining -= tokens
            } else if result.isEmpty {
                // Always include at least one chunk
                result.append(chunk)
                break
            }
        }
        return result
    }
}
