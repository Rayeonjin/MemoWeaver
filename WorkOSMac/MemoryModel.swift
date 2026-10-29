import Foundation
import SwiftUI

extension WorkOSModel {
    func bootstrapMemory() throws {
        invalidateMemoryDisplayCaches()
        guard let database else { return }
        // Convert legacy note-link arrays from earlier WorkOS JSON to durable graph links.
        let known = Set(notes.map(\.id))
        for note in notes {
            let raw = WorkOSJSON.dictionary(note.rawJSON)
            if let old = raw["links"] as? [String] {
                for target in old where known.contains(target) && target != note.id {
                    try database.addMemoryLink(MemoryLink("note:" + note.id, "note:" + target))
                }
            }
        }
        confirmedMemoryLinks = try database.confirmedLinks()
        inferredMemoryRelations = try database.aiMemoryRelations()
        inferredMemoryFacts = try database.aiMemoryFacts()
        memoryRelationReviews = try database.memoryRelationReviews()
        // Do not decode every stored bge-m3 embedding during ordinary note-taking.
        memoryVectors = []
        memoryCacheLoaded = false
        memoryIndexStatus = "AI 기억 도구를 열면 저장된 의미 색인을 불러옵니다."
    }

    func loadMemoryCache() {
        guard !memoryCacheLoaded, let database else { return }
        do {
            memoryVectors = try database.memoryVectors()
            invalidateMemoryDisplayCaches()
            memoryCacheLoaded = true
            memoryIndexStatus = memoryVectors.isEmpty ? "의미 색인이 없습니다. 필요하면 bge-m3 색인을 생성하세요." :
                "저장된 의미 색인 로드됨 · \(memoryVectors.count)개 구간"
        } catch {
            memoryIndexStatus = "저장된 의미 색인 로드 실패: " + error.localizedDescription
        }
    }

    func relationIsHidden(_ relation: MemoryInferredRelation) -> Bool {
        memoryRelationReviews.contains { $0.applies(to: relation) && $0.decision == "irrelevant" }
    }

    func setRelationReview(_ relation: MemoryInferredRelation, decision: String) {
        guard decision == "helpful" || decision == "irrelevant", let database else { return }
        do {
            let review = MemoryRelationReview(pairKey: relation.id,
                fromSignature: relation.fromSignature, toSignature: relation.toSignature,
                decision: decision, createdAt: WorkOSDate.now())
            try database.saveMemoryRelationReview(review)
            memoryRelationReviews = try database.memoryRelationReviews()
            invalidateMemoryDisplayCaches()
            regenerateMemoryGraphIfVisible()
            statusMessage = decision == "helpful" ? "유용한 기억 관계로 표시했습니다." : "무관한 연결을 숨겼습니다. 원문은 그대로입니다."
        } catch { show(error) }
    }

    func clearRelationReview(_ relation: MemoryInferredRelation) {
        guard let database else { return }
        do {
            try database.deleteMemoryRelationReview(relation.id)
            memoryRelationReviews = try database.memoryRelationReviews()
            invalidateMemoryDisplayCaches()
            regenerateMemoryGraphIfVisible()
        } catch { show(error) }
    }

    func memoryTimeline(for entityID: String) -> [MemoryTimelinePath] {
        MemoryTimelineCore.routes(focus: entityID, relations: activeInferredRelations(), limit: 3)
    }

    func memoryWithoutKnownFollowUp(for entityID: String) -> [MemoryFact] {
        MemoryTimelineCore.noFollowUpFound(for: entityID,
            facts: factsForSideMemory(entityID), relations: activeInferredRelations())
    }

    func regenerateMemoryGraphIfVisible() {
        if selectedPage == .memory { regenerateMemoryGraph() }
    }

    func regenerateMemoryGraph(query: String? = nil) {
        if let query { memoryGraphQuery = query }
        memoryGraph = MemoryEngine.graph(notes: notes, archives: archives,
            virtualMemories: virtualMemories,
            vectors: memoryVectors, confirmed: confirmedMemoryLinks,
            inferred: activeInferredRelations(),
            threshold: memoryThreshold, focusQuery: memoryGraphQuery)
    }

    func setMemoryThreshold(_ value: Double) {
        memoryThreshold = value
        UserDefaults.standard.set(value, forKey: "workos.memory.threshold")
        regenerateMemoryGraphIfVisible()
    }

    func memoryRelated(noteID: String) -> [MemoryNeighbor] {
        let valid = Set(notes.filter { $0.deletedAt.isEmpty }.map { "note:" + $0.id } +
            archives.map { "archive:" + $0.id } + virtualMemories.map { "virtual:" + $0.id })
        return MemoryEngine.related(entityID: "note:" + noteID,
            vectors: memoryVectors, threshold: memoryThreshold, maxCount: 6)
            .filter { valid.contains($0.id) }
    }

    // The right-side memory tab reads the existing SQLite-derived caches.
    // It NEVER triggers Ollama on every caret movement or typing event.
    func sideMemoryCenter(noteID: String, caretLine: Int) -> String {
        let sourceKey = "note:" + noteID
        guard !staleVirtualSources.contains(sourceKey) else { return sourceKey }
        let ranges: [SideMemoryRange]
        if let cached = sideRangeCache[noteID] {
            ranges = cached
        } else {
            ranges = virtualMemories.filter { $0.sourceKind == "note" && $0.sourceID == noteID }
                .map { SideMemoryRange(entityID: "virtual:" + $0.id, sourceNoteID: $0.sourceID,
                                       firstLine: $0.fromLine, lastLine: $0.toLine) }
            sideRangeCache[noteID] = ranges
        }
        return SideMemoryRules.focus(noteID: noteID, caretLine: caretLine, ranges: ranges)
    }

    func sideMemoryNeighbors(centerID: String, limit: Int = 5) -> [MemoryNeighbor] {
        let cacheKey = centerID + ":" + String(limit)
        if let cached = sideNeighborsCache[cacheKey] { return cached }
        let valid = Set(notes.filter { $0.deletedAt.isEmpty }.map { "note:" + $0.id } +
            archives.map { "archive:" + $0.id } + virtualMemories.map { "virtual:" + $0.id })
        guard valid.contains(centerID) else { return [] }
        let semantic = MemoryEngine.related(entityID: centerID, vectors: memoryVectors,
            threshold: memoryThreshold, maxCount: 40)
        let confirmed = confirmedMemoryLinks.compactMap { link -> String? in
            if link.first == centerID { return link.second }
            if link.second == centerID { return link.first }
            return nil
        }.sorted()
        let relationships = sideInferredRelations(centerID: centerID)
        let inferred = relationships.map { $0.fromID == centerID ? $0.toID : $0.fromID }
        let chosen = SideMemoryRules.neighborIDs(center: centerID, confirmed: confirmed + inferred,
            semantic: semantic.map(\.id), valid: valid, limit: limit)
        let lookup = Dictionary(uniqueKeysWithValues: semantic.map { ($0.id, $0) })
        let result = chosen.map { id in
            if let match = lookup[id] { return match }
            let virtual = virtualMemories.first { "virtual:" + $0.id == id }
            let archive = archives.first { "archive:" + $0.id == id }
            let kind = id.hasPrefix("virtual:") ? "virtual" :
                (id.hasPrefix("archive:") ? "archive" : "note")
            let relation = relationships.first {
                $0.fromID == id || $0.toID == id
            }
            return MemoryNeighbor(id: id, title: memoryTitle(id), kind: kind,
                similarity: 0, evidence: relation?.typeLabel ?? "직접 확정한 관계",
                fromLine: virtual?.fromLine ?? (archive == nil ? 0 : 1),
                toLine: virtual?.toLine ?? (archive?.lineCount ?? 0))
        }
        sideNeighborsCache[cacheKey] = result
        return result
    }

    func recommendedTypes(noteID: String, current: String) -> [MemoryCategoryAdvice] {
        MemoryEngine.classifications(neighbors: memoryRelated(noteID: noteID),
            notes: notes, categories: types, kind: "type", excluding: current)
    }

    func recommendedBooks(noteID: String, current: String) -> [MemoryCategoryAdvice] {
        MemoryEngine.classifications(neighbors: memoryRelated(noteID: noteID),
            notes: notes, categories: books, kind: "book", excluding: current)
    }

    func confirmedLinks(for id: String) -> [MemoryLink] {
        confirmedMemoryLinks.filter { $0.first == id || $0.second == id }
    }

    func memoryTitle(_ id: String) -> String {
        if id.hasPrefix("note:") {
            return notes.first(where: { "note:" + $0.id == id })?.visibleTitle ?? "삭제된 메모"
        }
        if id.hasPrefix("virtual:") {
            return virtualMemories.first(where: { "virtual:" + $0.id == id })?.title ?? "재분석이 필요한 가상 메모"
        }
        return archives.first(where: { "archive:" + $0.id == id })?.name ?? "삭제된 과거 자료"
    }

    // Memory map, sidebar, search and AI citations are references, not editor
    // navigation. Only an explicit "편집기에서 열기" action changes selection.
    func openMemoryNeighbor(_ neighbor: MemoryNeighbor) {
        openReferenceEntity(neighbor.id, fromLine: neighbor.fromLine, toLine: neighbor.toLine)
    }

    func openMemoryEntity(_ entityID: String) {
        openReferenceEntity(entityID)
    }

    func openReferenceEntity(_ entityID: String, fromLine: Int = 0, toLine: Int = 0) {
        guard let database else { return }
        do {
            guard let document = try database.evidenceDocument(entityID: entityID) else {
                statusMessage = "원본을 확인할 수 없습니다. 가상 메모를 다시 분석해 주세요."
                return
            }
            let isVirtual = entityID.hasPrefix("virtual:")
            let start = isVirtual ? document.fromLine : fromLine
            let end = isVirtual ? document.toLine : toLine
            let caption = isVirtual ? "가상 메모 · 원본 \(start)~\(end)행" :
                (start > 0 ? "원본 \(start)~\(end)행 주변 · 읽기 전용" : "읽기 전용 원본 메모")
            let shownBody = isVirtual ? document.text :
                MemoryReferenceCore.lineExcerpt(document.text, from: start, to: end)
            let snapshot = MemoryReferenceSnapshot(id: entityID, title: document.title,
                caption: caption, body: shownBody, editableEntityID: entityID)
            referenceReader.show(snapshot) { [weak self] in
                self?.openMemoryEntityForEditing(entityID, focusLine: start)
            }
        } catch { show(error) }
    }

    func openMemoryEntityForEditing(_ entityID: String, focusLine: Int = 0) {
        if entityID.hasPrefix("virtual:") {
            if let segment = virtualMemories.first(where: { "virtual:" + $0.id == entityID }) {
                openVirtualMemory(segment)
            }
        } else if entityID.hasPrefix("note:") {
            openNote(String(entityID.dropFirst(5)), focusLine: focusLine)
        } else if entityID.hasPrefix("archive:") {
            openArchiveExcerpt(String(entityID.dropFirst(8)),
                               fromLine: focusLine, toLine: focusLine)
        }
    }

    func addConfirmedMemoryLink(_ first: String, _ second: String,
                                relationKind: String = "related", memo: String = "",
                                replaceExisting: Bool = false) {
        guard first != second && !first.isEmpty && !second.isEmpty, let database else { return }
        do {
            let valid = Set(notes.filter { $0.deletedAt.isEmpty }.map { "note:" + $0.id } +
                archives.map { "archive:" + $0.id } + virtualMemories.map { "virtual:" + $0.id })
            guard valid.contains(first) && valid.contains(second) else { return }
            let proposed = MemoryLink(first, second,
                relationKind: ReferencePanelCore.sanitizeKind(relationKind), memo: memo)
            if replaceExisting { try database.upsertMemoryLink(proposed) }
            else { try database.addMemoryLink(proposed) }
            confirmedMemoryLinks = try database.confirmedLinks()
            invalidateMemoryDisplayCaches()
            regenerateMemoryGraphIfVisible()
            statusMessage = "기억 연결 확정 · 양방향 저장"
        } catch { show(error) }
    }

    func removeConfirmedMemoryLink(_ first: String, _ second: String) {
        guard let database else { return }
        do {
            try database.removeMemoryLink(MemoryLink(first, second))
            confirmedMemoryLinks = try database.confirmedLinks()
            invalidateMemoryDisplayCaches()
            regenerateMemoryGraphIfVisible()
            statusMessage = "기억 연결 해제됨"
        } catch { show(error) }
    }

    func stopAutomaticMemoryIndex() {
        backgroundModeDidChange()
    }

    // Editing only queues IDs; the scheduler waits until the Mac is available.
    func queueLiveMemoryIndex(noteID: String) {
        requestBackgroundIndex(noteID: noteID)
    }

    func updateMemoryForNote(_ noteID: String) async -> Bool {
        guard let database, let note = notes.first(where: { $0.id == noteID }) else { return false }
        do {
            let items = allMemoryIndexItems(notes: [note], chunks: [])
            let signatures = try database.memorySignatures()
            var changed = false
            for item in items where signatures[item.id] != item.signature {
                if Task.isCancelled { return false }
                let vectors = try await ollama.embed([item.text])
                guard !Task.isCancelled else { return false }
                // A newer note edit must not be overwritten by a stale response.
                guard let latest = notes.first(where: { $0.id == noteID }) else { return false }
                let fresh = allMemoryIndexItems(notes: [latest], chunks: [])
                guard fresh.contains(where: { $0.id == item.id && $0.signature == item.signature }) else { return false }
                try database.saveMemoryVector(item: item, model: "bge-m3", vector: vectors[0])
                changed = true
            }
            // Prune removed parts only for the edited note.
            let valid = Set(items.map(\.id))
            for key in signatures.keys where key.hasPrefix("note:" + noteID + ":") && !valid.contains(key) {
                try database.removeMemoryIndexItem(key)
                changed = true
            }
            if changed {
                memoryVectors = try database.memoryVectors()
                invalidateMemoryDisplayCaches()
                regenerateMemoryGraphIfVisible()
                memoryIndexStatus = "의미 연결 갱신됨 · \(memoryVectors.count)개 구간"
            }
            return true
        } catch {
            memoryIndexStatus = "자동 의미 색인 대기: \(error.localizedDescription)"
            return false
        }
    }

    func startMemoryIndex(automatic: Bool = false) {
        guard !isIndexingMemory, let database else { return }
        loadMemoryCache()
        guard embeddingAvailable else {
            memoryIndexStatus = "Ollama에서 bge-m3 모델을 확인한 후 색인할 수 있습니다."
            return
        }
        isIndexingMemory = true
        isAutomaticMemoryIndexing = automatic
        memoryIndexProgress = 0
        memoryIndexTask = Task { @MainActor in
            defer { isIndexingMemory = false; isAutomaticMemoryIndexing = false }
            do {
                let items = allMemoryIndexItems(notes: notes, chunks: chunks)
                let current = try database.memorySignatures()
                // Do not delete old vectors until the new index is ready.
                let pending = items.filter { current[$0.id] != $0.signature }
                let total = pending.count
                memoryIndexStatus = total == 0 ? "색인이 최신 상태입니다." : "의미 색인 생성 중 · 0 / \(total) 구간"
                var completed = 0
                var offset = 0
                while offset < pending.count {
                    try Task.checkCancellation()
                    let end = min(offset + 4, pending.count)
                    let batch = Array(pending[offset..<end])
                    let vectors = try await ollama.embed(batch.map(\.text))
                    try Task.checkCancellation()
                    // Recheck only the few notes in this batch: avoid rebuilding every
                    // archive and note on every network response (O(batch count * corpus)).
                    let noteIDs = Set(batch.filter { $0.kind == "note" }.compactMap { item -> String? in
                        guard item.entityID.hasPrefix("note:") else { return nil }
                        return String(item.entityID.dropFirst(5))
                    })
                    let liveNotes = notes.filter { noteIDs.contains($0.id) }
                    let liveNoteHashes = Dictionary(uniqueKeysWithValues:
                        allMemoryIndexItems(notes: liveNotes, chunks: []).map { ($0.id, $0.signature) })
                    let activeArchiveItems = Set(chunks.map { "archive:" + String($0.id) })
                    // Check virtual *part* IDs and content fingerprints, not
                    // their parent entity IDs. Re-analysis may change titles or
                    // boundaries while an Ollama embedding request is in flight.
                    let requestedVirtualIDs = Set(batch.filter { $0.kind == "virtual" }.map(\.entityID))
                    let liveVirtuals = virtualMemories.filter {
                        requestedVirtualIDs.contains("virtual:" + $0.id)
                    }
                    var liveVirtualTexts: [String: String] = [:]
                    for segment in liveVirtuals {
                        let key = segment.sourceKind + ":" + segment.sourceID
                        if liveVirtualTexts[key] == nil {
                            liveVirtualTexts[key] = virtualSource(kind: segment.sourceKind, id: segment.sourceID)
                        }
                    }
                    let liveVirtualHashes = Dictionary(uniqueKeysWithValues:
                        MemoryEngine.items(notes: [], chunks: [], virtualMemories: liveVirtuals,
                            virtualSourceTexts: liveVirtualTexts).map { ($0.id, $0.signature) })
                    for (item, vector) in zip(batch, vectors) {
                        let valid: Bool
                        switch item.kind {
                        case "note": valid = liveNoteHashes[item.id] == item.signature
                        case "virtual": valid = liveVirtualHashes[item.id] == item.signature
                        default: valid = activeArchiveItems.contains(item.id)
                        }
                        if valid { try database.saveMemoryVector(item: item, model: "bge-m3", vector: vector) }
                    }
                    completed += batch.count
                    offset = end
                    memoryIndexProgress = total == 0 ? 1 : Double(completed) / Double(total)
                    memoryIndexStatus = "의미 색인 생성 중 · \(completed) / \(total) 구간"
                    if completed % 24 == 0 {
                        memoryVectors = try database.memoryVectors()
                        invalidateMemoryDisplayCaches()
                        regenerateMemoryGraphIfVisible()
                    }
                }
                try Task.checkCancellation()
                // Respect note edits/deletions made while the long indexing task ran.
                let latestItems = allMemoryIndexItems(notes: notes, chunks: chunks)
                try database.removeObsoleteVectors(validKeys: Set(latestItems.map(\.id)))
                memoryVectors = try database.memoryVectors()
                invalidateMemoryDisplayCaches()
                regenerateMemoryGraphIfVisible()
                memoryIndexProgress = 1
                let savedSignatures = try database.memorySignatures()
                let remaining = latestItems.filter { savedSignatures[$0.id] != $0.signature }.count
                memoryIndexStatus = remaining == 0 ?
                    "의미 색인 완료 · \(memoryVectors.count)개 구간 / \(Set(memoryVectors.map(\.entityID)).count)개 기록" :
                    "기존 색인 완료. 작성 중 바뀐 \(remaining)개 구간은 색인 갱신이 필요합니다."
            } catch is CancellationError {
                memoryIndexStatus = "색인 일시 중지 · 재실행하면 완료된 구간부터 재개합니다."
                if let vectors = try? database.memoryVectors() { memoryVectors = vectors }
            } catch {
                memoryIndexStatus = "의미 색인 오류 · \(error.localizedDescription)"
                if let vectors = try? database.memoryVectors() { memoryVectors = vectors }
            }
        }
    }

    func stopMemoryIndex() { memoryIndexTask?.cancel() }

    // Enrich explicit AI questions with already verified first-hand sources
    // reached through directed memory relationships. Never substitute an AI
    // summary for source text; quoted evidence is carried as a label only.
    func sourcesWithMemoryContext(_ originals: [MemorySource]) -> [MemorySource] {
        guard let database, !originals.isEmpty else { return originals }
        var results = originals
        var selected: Set<String> = Set(originals.map { source in
            source.id.hasPrefix("virtual:") ? source.id :
                (source.kind == "archive" ? "archive:" + source.sourceID : "note:" + source.sourceID)
        })
        let verified = activeInferredRelations()
        let roots = Array(selected)
        for root in roots {
            for link in verified where link.fromID == root || link.toID == root {
                guard results.count < 10 else { return results }
                let targetID = link.fromID == root ? link.toID : link.fromID
                if selected.contains(targetID) { continue }
                guard let record = try? database.evidenceDocument(entityID: targetID) else { continue }
                let type = targetID.hasPrefix("virtual:") ? "virtual" :
                    (targetID.hasPrefix("archive:") ? "archive" : "note")
                let kind: String = type == "virtual" ?
                    (virtualMemories.first(where: { "virtual:" + $0.id == targetID })?.sourceKind ?? "note") : type
                let sourceID: String
                if type == "virtual" {
                    sourceID = virtualMemories.first(where: { "virtual:" + $0.id == targetID })?.sourceID ?? ""
                } else {
                    sourceID = String(targetID.dropFirst(type == "archive" ? 8 : 5))
                }
                if sourceID.isEmpty { continue }
                let exactQuote = link.fromID == targetID ? link.fromQuote : link.toQuote
                let subtitle = "AI 추론 · " + link.typeLabel + " · 출처 확인 가능"
                results.append(MemorySource(id: targetID, kind: kind, sourceID: sourceID,
                    title: record.title, subtitle: subtitle,
                    text: "연결 근거(원문 인용): " + exactQuote + "\n\n" + record.excerpt,
                    fromLine: record.fromLine, toLine: record.toLine, score: 0))
                selected.insert(targetID)
            }
        }
        return results
    }

    func hybridMemorySources(for question: String) async -> [MemorySource] {
        let sourcesText = virtualSourceTexts()
        let keyword = WorkOSSearch.find(question: question, notes: notes, chunks: chunks,
            limit: 8, virtualMemories: virtualMemories, virtualSourceTexts: sourcesText)
        guard embeddingAvailable, !memoryVectors.isEmpty else { return sourcesWithMemoryContext(keyword) }
        do {
            let query = try await ollama.embed([question])
            guard let vector = query.first else { return sourcesWithMemoryContext(keyword) }
            let all = MemoryEngine.items(notes: notes, chunks: chunks,
                virtualMemories: virtualMemories, virtualSourceTexts: sourcesText)
            let byKey = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
            var ranked: [(MemoryIndexItem, Double)] = []
            for index in memoryVectors {
                guard let item = byKey[index.id], item.signature == index.signature else { continue }
                let similarity = MemoryEngine.cosine(vector, index.values)
                if similarity >= max(0.40, memoryThreshold - 0.12) { ranked.append((item, similarity)) }
            }
            ranked.sort { $0.1 > $1.1 }
            var sources: [MemorySource] = []
            var selectedEntities: Set<String> = []
            var virtualParentCount: [String: Int] = [:]
            for (item, similarity) in ranked {
                if selectedEntities.contains(item.entityID) { continue }
                if item.kind == "virtual" {
                    let parent = item.sourceKind + ":" + item.sourceID
                    if virtualParentCount[parent, default: 0] >= 3 { continue }
                    virtualParentCount[parent, default: 0] += 1
                }
                let resolvedKind = item.kind == "virtual" ? item.sourceKind : item.kind
                let resolvedID = item.kind == "virtual" ? item.sourceID :
                    String(item.entityID.dropFirst(item.kind == "note" ? 5 : 8))
                sources.append(MemorySource(id: item.kind == "virtual" ? item.entityID : item.id,
                    kind: resolvedKind,
                    sourceID: resolvedID, title: item.title,
                    subtitle: item.kind == "virtual" ? "가상 메모(제안) · \(item.fromLine)~\(item.toLine)행" :
                        (item.kind == "archive" ? "의미 검색 · \(item.fromLine)~\(item.toLine)행" : "의미 검색"),
                    text: item.text, fromLine: item.fromLine, toLine: item.toLine,
                    score: Int(similarity * 100)))
                selectedEntities.insert(item.entityID)
                if sources.count >= 5 { break }
            }
            for source in keyword {
                let id = source.id.hasPrefix("virtual:") ? source.id :
                    (source.kind == "archive" ? "archive:" + source.sourceID : "note:" + source.sourceID)
                if selectedEntities.contains(id) { continue }
                sources.append(source)
                selectedEntities.insert(id)
                if sources.count >= 8 { break }
            }
            return sourcesWithMemoryContext(sources)
        } catch {
            memoryIndexStatus = "질문 의미 검색 실패 · 키워드 검색으로 대체: \(error.localizedDescription)"
            return sourcesWithMemoryContext(keyword)
        }
    }
}
