import Foundation

// Recomputable AI search data is kept separate from the note/revision JSON.
struct MemoryIndexItem: Identifiable, Hashable {
    var id: String                // stable chunk key: note:<UUID>:<part> or archive:<chunkID>
    var entityID: String          // note:<UUID> or archive:<UUID>
    var kind: String              // note | archive
    var title: String
    var text: String
    var fromLine: Int = 0
    var toLine: Int = 0
    var sourceID: String = ""          // parent record of virtual item
    var sourceKind: String = ""        // note | archive
    var signature: String { MemoryEngine.fingerprint(text) }
}

struct MemoryVector: Identifiable {
    var id: String
    var entityID: String
    var kind: String
    var title: String
    var signature: String
    var values: [Double]
    var fromLine: Int
    var toLine: Int
}

struct MemoryLink: Identifiable, Hashable {
    static func sanitizeKind(_ kind: String) -> String {
        ["related", "follow_up", "resolves", "supports", "contrasts"].contains(kind) ? kind : "related"
    }
    var first: String
    var second: String
    var createdAt: String
    var relationKind: String
    var memo: String
    var id: String { first + "|" + second }

    init(_ a: String, _ b: String, createdAt: String = WorkOSDate.now(),
         relationKind: String = "related", memo: String = "") {
        first = min(a, b)
        second = max(a, b)
        self.createdAt = createdAt
        self.relationKind = relationKind
        self.memo = memo
    }
}

struct MemoryNeighbor: Identifiable {
    let id: String               // entityID
    let title: String
    let kind: String
    let similarity: Double
    let evidence: String
    let fromLine: Int
    let toLine: Int
}

struct MemoryCategoryAdvice: Identifiable {
    let id: String
    let name: String
    let score: Double
    let evidence: String
}

struct MemoryGraphNode: Identifiable {
    let id: String
    let title: String
    let kind: String
    let subtitle: String
    var cluster: Int = 0
}

struct MemoryGraphEdge: Identifiable {
    let first: String
    let second: String
    let strength: Double
    let confirmed: Bool
    var inferredType: String = ""
    var id: String { min(first, second) + "|" + max(first, second) }
}

struct MemoryGraphData {
    var nodes: [MemoryGraphNode] = []
    var edges: [MemoryGraphEdge] = []
    var indexedEntities: Int = 0
}

enum MemoryEngine {
    // Stable, non-cryptographic revision signature. Not used for integrity/security.
    static func fingerprint(_ input: String) -> String {
        var result: UInt64 = 14695981039346656037
        for byte in input.utf8 {
            result = (result ^ UInt64(byte)) &* 1099511628211
        }
        return String(result, radix: 16)
    }

    static func items(notes: [WorkNote], chunks: [WorkChunk],
                      virtualMemories: [VirtualMemory] = [],
                      virtualSourceTexts: [String: String] = [:]) -> [MemoryIndexItem] {
        var result: [MemoryIndexItem] = []
        let sourceSignatures = virtualSourceTexts.mapValues(VirtualMemoryCore.signature)
        let usable = virtualMemories.filter { item in
            sourceSignatures[item.sourceKind + ":" + item.sourceID] == item.sourceSignature
        }
        let segmentedNotes = Set(usable.filter { $0.sourceKind == "note" }.map(\.sourceID))
        let segmentedArchives = Set(usable.filter { $0.sourceKind == "archive" }.map(\.sourceID))
        for note in notes where note.deletedAt.isEmpty {
            let progress = note.progress.map { HTMLText.plain(WorkOSJSON.string($0, "body")) }.joined(separator: "\n")
            let content = "제목: \(note.visibleTitle)\n\(note.plainBody)\n\(progress)"
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if content.isEmpty || (note.title.isEmpty && note.plainBody.isEmpty && progress.isEmpty) { continue }
            // Once an intact virtual index exists, avoid duplicate generic
            // windows for this note. Saved revisions remain independently indexed.
            let characters = Array(segmentedNotes.contains(note.id) ? "" : content)
            let strideSize = 1300
            let windowSize = 1500
            var start = 0
            var part = 0
            while start < characters.count {
                let end = min(characters.count, start + windowSize)
                result.append(MemoryIndexItem(id: "note:\(note.id):\(part)",
                    entityID: "note:\(note.id)", kind: "note", title: note.visibleTitle,
                    text: String(characters[start..<end])))
                if end == characters.count { break }
                start += strideSize
                part += 1
            }
            // Progress entries do not belong to the editor body; a virtual
            // split must not hide them from semantic retrieval.
            if segmentedNotes.contains(note.id), !progress.isEmpty {
                result.append(MemoryIndexItem(id: "note:\(note.id):progress",
                    entityID: "note:\(note.id)", kind: "note", title: note.visibleTitle,
                    text: "진행 기록 · " + String(progress.prefix(1800))))
            }
            // Recent saved revisions are searchable, without replacing the current note.
            // Cap the number so an old heavily edited note cannot dominate indexing.
            for revision in note.revisions.suffix(4) {
                let source = WorkOSJSON.string(revision, "body")
                let body = WorkOSJSON.string(revision, "bodyFormat") == "markdown"
                    ? source : HTMLText.plain(source)
                guard !body.isEmpty else { continue }
                let at = WorkOSJSON.string(revision, "at")
                let originalID = WorkOSJSON.string(revision, "id", default: MemoryEngine.fingerprint(at + body))
                let text = "과거 저장 버전 · \(at) · \(note.visibleTitle)\n" + String(body.prefix(1500))
                result.append(MemoryIndexItem(id: "note:\(note.id):revision:\(originalID)",
                    entityID: "note:\(note.id)", kind: "note", title: note.visibleTitle,
                    text: text))
            }
        }
        for chunk in chunks where !segmentedArchives.contains(chunk.sourceID) {
            if !chunk.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.append(MemoryIndexItem(id: "archive:\(chunk.id)",
                    entityID: "archive:\(chunk.sourceID)", kind: "archive", title: chunk.title,
                    text: String(chunk.text.prefix(2400)), fromLine: chunk.fromLine, toLine: chunk.toLine))
            }
        }
        // Each virtual region has its own entity ID. This makes it independently
        // searchable/connectable while retaining the original parent source ID.
        // Cache source lines once per parent to avoid quadratic rescanning.
        let bySource = Dictionary(grouping: usable) { $0.sourceKind + ":" + $0.sourceID }
        for (key, segments) in bySource {
            guard let source = virtualSourceTexts[key] else { continue }
            let all = VirtualMemoryCore.lines(source)
            for segment in segments {
                let text = all[(segment.fromLine - 1)..<segment.toLine].joined(separator: "\n")
                let characters = Array(text)
                var offset = 0, part = 0
                while offset < characters.count {
                    let end = min(characters.count, offset + 2200)
                    let excerpt = String(characters[offset..<end])
                    if !excerpt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        result.append(MemoryIndexItem(id: "virtual:" + segment.id + ":part:" + String(part),
                            entityID: "virtual:" + segment.id, kind: "virtual", title: segment.title,
                            text: "가상 메모 제목(추정): " + segment.title + "\n" + excerpt,
                            fromLine: segment.fromLine, toLine: segment.toLine,
                            sourceID: segment.sourceID, sourceKind: segment.sourceKind))
                    }
                    if end == characters.count { break }
                    offset += 2000 // small overlap protects references near windows
                    part += 1
                }
            }
        }
        return result
    }

    static func cosine(_ a: [Double], _ b: [Double]) -> Double {
        guard !a.isEmpty && a.count == b.count else { return 0 }
        var dot = 0.0
        var aa = 0.0
        var bb = 0.0
        for i in a.indices {
            dot += a[i] * b[i]
            aa += a[i] * a[i]
            bb += b[i] * b[i]
        }
        guard aa > 0, bb > 0 else { return 0 }
        let value = dot / (sqrt(aa) * sqrt(bb))
        return value.isFinite ? min(1, max(-1, value)) : 0
    }

    static func related(entityID: String, vectors: [MemoryVector], threshold: Double,
                        maxCount: Int = 6) -> [MemoryNeighbor] {
        let seeds = vectors.filter { $0.entityID == entityID }
        guard !seeds.isEmpty else { return [] }
        var matches: [String: MemoryNeighbor] = [:]
        for candidate in vectors where candidate.entityID != entityID {
            var best = -1.0
            for seed in seeds {
                best = max(best, cosine(seed.values, candidate.values))
            }
            if best < threshold { continue }
            if let old = matches[candidate.entityID], old.similarity >= best { continue }
            matches[candidate.entityID] = MemoryNeighbor(id: candidate.entityID,
                title: candidate.title, kind: candidate.kind, similarity: best,
                evidence: candidate.kind == "archive" || candidate.kind == "virtual" ? "원문 \(candidate.fromLine)~\(candidate.toLine)행" : "본문 의미 유사성",
                fromLine: candidate.fromLine, toLine: candidate.toLine)
        }
        return Array(matches.values).sorted { $0.similarity > $1.similarity }.prefix(maxCount).map { $0 }
    }

    static func classifications(neighbors: [MemoryNeighbor], notes: [WorkNote],
                                categories: [WorkCategory], kind: String, excluding existing: String) -> [MemoryCategoryAdvice] {
        var scores: [String: Double] = [:]
        var evidence: [String: (name: String, score: Double)] = [:]
        for neighbor in neighbors where neighbor.kind == "note" {
            guard let reference = notes.first(where: { "note:" + $0.id == neighbor.id }) else { continue }
            let category = kind == "type" ? reference.typeID : reference.bookID
            guard !category.isEmpty, category != existing else { continue }
            let weight = max(0, neighbor.similarity - 0.25)
            scores[category, default: 0] += weight
            if weight > (evidence[category]?.score ?? -1) {
                evidence[category] = (reference.visibleTitle, weight)
            }
        }
        return scores.compactMap { key, value -> MemoryCategoryAdvice? in
            guard let category = categories.first(where: { $0.id == key }) else { return nil }
            return MemoryCategoryAdvice(id: key, name: category.name, score: value,
                evidence: evidence[key]?.name ?? "관련 메모")
        }.sorted { $0.score > $1.score }.prefix(2).map { $0 }
    }

    static func graph(notes: [WorkNote], archives: [WorkArchive],
                      virtualMemories: [VirtualMemory] = [], vectors: [MemoryVector],
                      confirmed: [MemoryLink], inferred: [MemoryInferredRelation] = [],
                      threshold: Double, maxNodes: Int = 110,
                      focusQuery: String = "") -> MemoryGraphData {
        // Keep memory map responsive; recent / pinned notes and confirmed endpoints first.
        let pinnedEndpoints = Set(confirmed.flatMap { [$0.first, $0.second] } +
            inferred.filter(\.hasRelationship).flatMap { [$0.fromID, $0.toID] })
        let key = focusQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let sortedNotes = notes.filter { $0.deletedAt.isEmpty }.sorted { a, b in
            let aMatch = !key.isEmpty && (a.title.lowercased().contains(key) || a.plainBody.lowercased().contains(key))
            let bMatch = !key.isEmpty && (b.title.lowercased().contains(key) || b.plainBody.lowercased().contains(key))
            if aMatch != bMatch { return aMatch }
            let aPinned = a.pinned || pinnedEndpoints.contains("note:" + a.id)
            let bPinned = b.pinned || pinnedEndpoints.contains("note:" + b.id)
            if aPinned != bPinned { return aPinned }
            return a.updatedAt > b.updatedAt
        }
        var nodes: [MemoryGraphNode] = []
        let reservedArchives = min(15, archives.count)
        let reservedVirtuals = min(30, virtualMemories.count)
        for note in sortedNotes.prefix(max(0, maxNodes - reservedArchives - reservedVirtuals)) {
            nodes.append(MemoryGraphNode(id: "note:" + note.id, title: note.visibleTitle,
                kind: "note", subtitle: note.noteDate))
        }
        // Archive files are nodes, not thousands of separate line chunks.
        let archived = archives.sorted { a, b in
            let aMatch = !key.isEmpty && a.name.lowercased().contains(key)
            let bMatch = !key.isEmpty && b.name.lowercased().contains(key)
            if aMatch != bMatch { return aMatch }
            let ap = pinnedEndpoints.contains("archive:" + a.id)
            let bp = pinnedEndpoints.contains("archive:" + b.id)
            return ap == bp ? a.addedAt > b.addedAt : ap
        }
        for archive in archived.prefix(min(reservedArchives, max(0, maxNodes - nodes.count))) {
            nodes.append(MemoryGraphNode(id: "archive:" + archive.id, title: archive.name,
                kind: "archive", subtitle: "과거 TXT · \(archive.lineCount)행"))
        }
        let orderedVirtuals = virtualMemories.sorted { a, b in
            let am = !key.isEmpty && a.title.lowercased().contains(key)
            let bm = !key.isEmpty && b.title.lowercased().contains(key)
            if am != bm { return am }
            let ap = pinnedEndpoints.contains("virtual:" + a.id)
            let bp = pinnedEndpoints.contains("virtual:" + b.id)
            if ap != bp { return ap }
            return a.createdAt > b.createdAt ? true :
                (a.createdAt == b.createdAt && a.fromLine < b.fromLine)
        }
        for segment in orderedVirtuals.prefix(min(reservedVirtuals, max(0, maxNodes - nodes.count))) {
            nodes.append(MemoryGraphNode(id: "virtual:" + segment.id, title: segment.title,
                kind: "virtual", subtitle: "가상 메모 · 원문 \(segment.lineLabel)"))
        }
        let ids = Set(nodes.map(\.id))
        var grouped: [String: [[Double]]] = [:]
        for vector in vectors where ids.contains(vector.entityID) {
            grouped[vector.entityID, default: []].append(vector.values)
        }
        // For a huge TXT file, the map samples chunks across the file; focused search
        // continues to use all indexed chunks, including lines near the file's end.
        for (entity, all) in grouped where all.count > 12 {
            grouped[entity] = (0..<12).map { i in
                all[min(all.count - 1, i * (all.count - 1) / 11)]
            }
        }
        var options: [MemoryGraphEdge] = []
        // Compare each entity pair using its best matching pair of chunks.
        let active = nodes.map(\.id).filter { grouped[$0] != nil }
        if active.count > 1 {
            for i in 0..<(active.count - 1) {
                for j in (i + 1)..<active.count {
                    let a = active[i], b = active[j]
                    var best = -1.0
                    for av in grouped[a] ?? [] {
                        for bv in grouped[b] ?? [] { best = max(best, cosine(av, bv)) }
                    }
                    if best >= threshold {
                        options.append(MemoryGraphEdge(first: a, second: b, strength: best, confirmed: false))
                    }
                }
            }
        }
        options.sort { $0.strength > $1.strength }
        var degree: [String: Int] = [:]
        var edges: [MemoryGraphEdge] = []
        for option in options where edges.count < maxNodes * 2 {
            if degree[option.first, default: 0] >= 3 || degree[option.second, default: 0] >= 3 { continue }
            edges.append(option)
            degree[option.first, default: 0] += 1
            degree[option.second, default: 0] += 1
        }
        // Grounded AI relations replace similarity edges, but never user-confirmed links.
        let confirmedIDs = Set(confirmed.map(\.id))
        for relation in inferred where relation.hasRelationship &&
            ids.contains(relation.fromID) && ids.contains(relation.toID) &&
            !confirmedIDs.contains(relation.id) {
            edges.removeAll { $0.id == relation.id }
            edges.append(MemoryGraphEdge(first: relation.fromID, second: relation.toID,
                strength: 0.99, confirmed: false, inferredType: relation.typeLabel))
        }
        for link in confirmed where ids.contains(link.first) && ids.contains(link.second) {
            edges.removeAll { $0.id == link.id }
            edges.append(MemoryGraphEdge(first: link.first, second: link.second,
                strength: 1, confirmed: true))
        }
        // Connected components act as explainable, deterministic visual clusters.
        var parents: [String: String] = Dictionary(uniqueKeysWithValues: ids.map { ($0, $0) })
        func find(_ id: String) -> String {
            var current = id
            while let p = parents[current], p != current { current = p }
            return current
        }
        for edge in edges {
            let a = find(edge.first), b = find(edge.second)
            if a != b { parents[max(a, b)] = min(a, b) }
        }
        let roots = Array(Set(nodes.map { find($0.id) })).sorted()
        let groups = Dictionary(uniqueKeysWithValues: roots.enumerated().map { ($0.element, $0.offset) })
        for index in nodes.indices { nodes[index].cluster = groups[find(nodes[index].id)] ?? 0 }
        return MemoryGraphData(nodes: nodes, edges: edges,
            indexedEntities: Set(vectors.map(\.entityID)).count)
    }
}
