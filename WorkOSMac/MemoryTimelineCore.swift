import Foundation

/// A path is a sequence of cited, directionally linked records. We do not
/// synthesize dates or treat textual/semantic proximity as a causal edge.
struct MemoryTimelinePath: Identifiable {
    let entities: [String]
    let relationships: [MemoryInferredRelation]
    var id: String { entities.joined(separator: "->") }
}

enum MemoryTimelineCore {
    static let temporalTypes: Set<String> = ["follow_up", "resolves", "changes"]

    static func routes(focus: String, relations: [MemoryInferredRelation],
                       maxDepth: Int = 3, limit: Int = 4) -> [MemoryTimelinePath] {
        let edges = relations.filter { $0.hasRelationship && temporalTypes.contains($0.relationType) }
        let forwardIndex = Dictionary(grouping: edges, by: \.fromID)
        let backwardIndex = Dictionary(grouping: edges, by: \.toID)
        var paths: [MemoryTimelinePath] = []
        // Bounded graph walk: indexing and a per-node cap prevent a dense
        // historical corpus from making the editor-side memory pane lag.
        for forward in [false, true] {
            var queue: [MemoryTimelinePath] = [MemoryTimelinePath(entities: [focus], relationships: [])]
            var cursor = 0
            while cursor < queue.count && cursor < 100 {
                let current = queue[cursor]
                cursor += 1
                if !current.relationships.isEmpty { paths.append(current) }
                if current.relationships.count >= maxDepth { continue }
                guard let endpoint = current.entities.last else { continue }
                let candidates = (forward ? forwardIndex[endpoint] : backwardIndex[endpoint]) ?? []
                for edge in candidates.prefix(8) {
                    let next = forward ? edge.toID : edge.fromID
                    if current.entities.contains(next) { continue }
                    queue.append(MemoryTimelinePath(entities: current.entities + [next],
                        relationships: current.relationships + [edge]))
                }
            }
        }
        // Prefer longer, source-grounded paths, with deterministic ties.
        return Array(paths.sorted {
            if $0.relationships.count != $1.relationships.count {
                return $0.relationships.count > $1.relationships.count
            }
            return $0.id < $1.id
        }.prefix(limit))
    }

    /// A missing known follow-up is NOT proof that an issue is unresolved.
    /// Return only issues for which the available analysis has not discovered
    /// a direct follow-up/resolution (informational, not a task status).
    static func noFollowUpFound(for focus: String, facts: [MemoryFact],
                                relations: [MemoryInferredRelation]) -> [MemoryFact] {
        let hasNext = relations.contains {
            $0.fromID == focus && ($0.relationType == "resolves" || $0.relationType == "follow_up")
        }
        if hasNext { return [] }
        return Array(facts.filter { $0.entityID == focus &&
            ($0.kind == "problem" || $0.kind == "question") }.prefix(3))
    }
}

/// A feedback decision is valid only for the exact source revisions it was
/// given for. Editing either original permits renewed AI evaluation.
struct MemoryRelationReview: Codable, Identifiable, Hashable {
    let pairKey: String
    let fromSignature: String
    let toSignature: String
    let decision: String // helpful | irrelevant
    let createdAt: String
    var id: String { pairKey }

    func applies(to relation: MemoryInferredRelation) -> Bool {
        pairKey == relation.id && fromSignature == relation.fromSignature &&
        toSignature == relation.toSignature
    }
}
