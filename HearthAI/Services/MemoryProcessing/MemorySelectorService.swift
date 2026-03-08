import Foundation

enum MemorySelectorService {

    /// Selects the most relevant memories for a query using TF-IDF
    /// scoring. Returns memories sorted by relevance, up to
    /// `maxTokenBudget` total estimated tokens.
    static func selectMemories(
        query: String,
        memories: [Memory],
        maxTokenBudget: Int
    ) -> [Memory] {
        let active = memories.filter(\.isActive)
        guard !active.isEmpty, !query.isEmpty else { return [] }

        let queryTerms = tokenize(query)
        guard !queryTerms.isEmpty else {
            return takeWithinBudget(
                active.sorted { $0.updatedAt > $1.updatedAt },
                budget: maxTokenBudget
            )
        }

        let totalDocs = Double(active.count)
        var idf: [String: Double] = [:]
        for term in queryTerms {
            let docsWithTerm = active.filter {
                tokenize($0.content).contains(term)
            }.count
            idf[term] = log(
                (totalDocs + 1) / (Double(docsWithTerm) + 1)
            ) + 1
        }

        let scored: [(memory: Memory, score: Double)] = active
            .map { memory in
                let tokens = tokenize(memory.content)
                let total = Double(tokens.count)
                guard total > 0 else {
                    return (memory: memory, score: 0)
                }

                var score = 0.0
                for term in queryTerms {
                    let freq = Double(
                        tokens.filter { $0 == term }.count
                    ) / total
                    score += freq * (idf[term] ?? 1.0)
                }
                return (memory: memory, score: score)
            }
            .sorted { $0.score > $1.score }

        return takeWithinBudget(
            scored.map(\.memory), budget: maxTokenBudget
        )
    }

    // MARK: - Private

    private static func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count > 2 }
    }

    private static func takeWithinBudget(
        _ memories: [Memory], budget: Int
    ) -> [Memory] {
        var result: [Memory] = []
        var remaining = budget
        for memory in memories {
            let tokens = Int(memory.tokenEstimate)
            if tokens <= remaining {
                result.append(memory)
                remaining -= tokens
            } else if result.isEmpty {
                result.append(memory)
                break
            }
        }
        return result
    }
}
