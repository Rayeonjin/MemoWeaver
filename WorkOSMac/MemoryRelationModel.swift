import Foundation
import SwiftUI

// The language model runs ONLY after an explicit user action. Typing, caret
// movement, opening a note, or showing a side panel must not invoke Ollama.
@MainActor
extension WorkOSModel {
    func sideInferredRelations(centerID: String) -> [MemoryInferredRelation] {
        if let cached = sideRelationCache[centerID] { return cached }
        guard let database else { return [] }
        let candidates = inferredMemoryRelations.filter {
            $0.hasRelationship && ($0.fromID == centerID || $0.toID == centerID)
        }
        var signatures: [String: String] = [:]
        var documents: [String: MemoryEvidenceDocument] = [:]
        for relation in candidates {
            for id in [relation.fromID, relation.toID] where signatures[id] == nil {
                if let document = try? database.evidenceDocument(entityID: id) {
                    signatures[id] = document.signature
                    documents[id] = document
                }
            }
        }
        let reviewLookup = Dictionary(uniqueKeysWithValues:
            memoryRelationReviews.map { ($0.pairKey, $0) })
        let current = MemoryRelationCore.relevant(to: centerID, relationships: candidates,
            signatures: signatures).filter { relation in
                let review = reviewLookup[relation.id]
                return !(review?.applies(to: relation) == true && review?.decision == "irrelevant") &&
                    documents[relation.fromID]?.excerpt.contains(relation.fromQuote) == true &&
                    documents[relation.toID]?.excerpt.contains(relation.toQuote) == true
            }.sorted { lhs, rhs in
                let left = reviewLookup[lhs.id]
                let right = reviewLookup[rhs.id]
                let leftHelpful = left?.applies(to: lhs) == true && left?.decision == "helpful"
                let rightHelpful = right?.applies(to: rhs) == true && right?.decision == "helpful"
                if leftHelpful != rightHelpful { return leftHelpful }
                return lhs.createdAt > rhs.createdAt
            }.prefix(10).map { $0 }
        sideRelationCache[centerID] = current
        return current
    }

    func activeInferredRelations() -> [MemoryInferredRelation] {
        if let cached = activeRelationCache { return cached }
        guard let database else { return [] }
        let entries = inferredMemoryRelations.filter(\.hasRelationship)
        var signatures: [String: String] = [:]
        var documents: [String: MemoryEvidenceDocument] = [:]
        for relation in entries {
            for id in [relation.fromID, relation.toID] where signatures[id] == nil {
                if let document = try? database.evidenceDocument(entityID: id) {
                    signatures[id] = document.signature
                    documents[id] = document
                }
            }
        }
        let reviewLookup = Dictionary(uniqueKeysWithValues:
            memoryRelationReviews.map { ($0.pairKey, $0) })
        let current = entries.filter { relation in
            let review = reviewLookup[relation.id]
            return !(review?.applies(to: relation) == true && review?.decision == "irrelevant") &&
                MemoryRelationCore.isCurrent(relation, signatures: signatures) &&
                documents[relation.fromID]?.excerpt.contains(relation.fromQuote) == true &&
                documents[relation.toID]?.excerpt.contains(relation.toQuote) == true
        }
        activeRelationCache = current
        return current
    }

    func factsForSideMemory(_ entityID: String) -> [MemoryFact] {
        if let cached = sideFactsCache[entityID] { return cached }
        guard let document = try? database?.evidenceDocument(entityID: entityID) else { return [] }
        let current = inferredMemoryFacts.filter {
            $0.entityID == entityID && $0.sourceSignature == document.signature &&
            document.excerpt.contains($0.quote)
        }.sorted { $0.ordinal < $1.ordinal }
        sideFactsCache[entityID] = current
        return current
    }

    // Keep the first version bounded and explainable. Candidate discovery
    // combines semantic similarity, user-confirmed links and explicit shared
    // words in the source. Similarity NEVER becomes a saved relationship itself.
    func startRelationAnalysis(centerID: String, automatic: Bool = false) {
        guard !isInferringMemory, !isIndexingMemory, let database else { return }
        guard aiConnected, !aiModelName.isEmpty else {
            inferenceStatus = "Ollama 채팅 모델을 먼저 연결하세요. bge-m3만으로 관계를 추론하지 않습니다."
            return
        }
        loadMemoryCache()
        guard let center = try? database.evidenceDocument(entityID: centerID) else {
            inferenceStatus = "현재 원문을 읽지 못했습니다. 메모를 저장하거나 가상 메모를 다시 분석하세요."
            return
        }
        var candidateIDs: [String] = []
        func appendCandidate(_ id: String) {
            if id != centerID && !candidateIDs.contains(id) { candidateIDs.append(id) }
        }
        // 1. A human-confirmed link is a strong candidate, but its type is
        // not automatically an AI finding.
        for link in confirmedLinks(for: centerID).prefix(2) {
            appendCandidate(link.first == centerID ? link.second : link.first)
        }
        // 2. Semantic similarity proposes a few other candidates (not proof).
        for entry in MemoryEngine.related(entityID: centerID, vectors: memoryVectors,
                                           threshold: max(0.38, memoryThreshold - 0.23), maxCount: 3) {
            appendCandidate(entry.id)
        }
        // 3. Literal overlapping context helps catch important related notes
        // that are not among the best bge-m3 embedding matches.
        // Candidate ranking lives in the Foundation-only core. Keep the
        // SwiftUI/ObservableObject entry point trivial so Apple's swiftc does
        // not have to infer a large chained map/filter/sort tuple expression.
        let lexicalIDs = MemoryRelationCore.lexicalCandidateIDs(
            center: center, notes: notes, virtualMemories: virtualMemories, archives: archives)
        for candidateID in lexicalIDs.prefix(5) { appendCandidate(candidateID) }
        let chosen = candidateIDs.filter {
            MemoryRelationCore.shouldConsider(centerID: centerID, candidateID: $0,
                                              virtualMemories: virtualMemories)
        }.prefix(6)
        // Even a standalone memory can contain a useful unresolved question
        // or decision. Extract its own facts when there are no pair candidates.
        let modelName = aiModelName
        isInferringMemory = true
        isAutomaticRelationAnalysis = automatic
        inferenceProgress = 0
        inferenceStatus = "근거 기반 관계 분석 준비 중 · 후보 \(chosen.count)개"
        relationInferenceTask = Task { @MainActor in
            defer { isInferringMemory = false; isAutomaticRelationAnalysis = false; relationInferenceTask = nil }
            do {
                let initialFacts = try await loadOrExtractFacts(center, modelName: modelName, database: database)
                var reviewed = 0, accepted = 0, noRelation = 0, invalid = 0, skipped = 0
                for candidateID in chosen {
                    try Task.checkCancellation()
                    guard let target = try database.evidenceDocument(entityID: candidateID) else {
                        skipped += 1
                        continue
                    }
                    let old = inferredMemoryRelations.first { $0.id == MemoryRelationCore.pairKey(centerID, candidateID) }
                    if let old, old.model == modelName,
                        ((old.fromID == centerID && old.fromSignature == center.signature && old.toSignature == target.signature) ||
                         (old.toID == centerID && old.toSignature == center.signature && old.fromSignature == target.signature)) {
                        skipped += 1
                    } else {
                        do {
                            let otherFacts = try await loadOrExtractFacts(target, modelName: modelName, database: database)
                            let raw = try await ollama.analyzeMemoryEvidence(model: modelName,
                                prompt: MemoryRelationCore.relationPrompt(center, target,
                                    factsA: initialFacts, factsB: otherFacts))
                            try Task.checkCancellation()
                            // Never accept a response if either source changed
                            // while the local model was thinking.
                            guard let liveA = try database.evidenceDocument(entityID: centerID),
                                  let liveB = try database.evidenceDocument(entityID: candidateID),
                                  liveA.signature == center.signature, liveB.signature == target.signature else {
                                skipped += 1
                                continue
                            }
                            let relation = try MemoryRelationCore.parseRelation(raw, a: center,
                                b: target, model: modelName, createdAt: WorkOSDate.now())
                            try database.saveAIRelation(relation)
                            inferredMemoryRelations = try database.aiMemoryRelations()
                            invalidateMemoryDisplayCaches()
                            if relation.hasRelationship { accepted += 1 }
                            else { noRelation += 1 }
                        } catch is CancellationError { throw CancellationError() }
                        catch { invalid += 1 } // no unverified relation is stored
                    }
                    reviewed += 1
                    inferenceProgress = Double(reviewed) / Double(max(1, chosen.count))
                    inferenceStatus = "관계 검토 \(reviewed)/\(chosen.count) · AI 관계 \(accepted) · 관계 없음 \(noRelation) · 검증 실패 \(invalid) · 재사용/보류 \(skipped)"
                }
                regenerateMemoryGraphIfVisible()
                if chosen.isEmpty { inferenceProgress = 1 }
                inferenceStatus = "AI 관계 분석 완료 · 근거 확인 \(accepted) · 관계 없음 \(noRelation) · 검증 실패 \(invalid) · 캐시/보류 \(skipped)"
            } catch is CancellationError {
                inferenceStatus = "관계 분석 중단 · 완료된 검증 결과만 남겼습니다."
            } catch {
                inferenceStatus = "관계 분석 오류 · 원본 보존: \(error.localizedDescription)"
            }
        }
    }

    private func loadOrExtractFacts(_ document: MemoryEvidenceDocument,
                                    modelName: String, database: LocalDatabase) async throws -> [MemoryFact] {
        let previous = inferredMemoryFacts.filter {
            $0.entityID == document.id && $0.sourceSignature == document.signature && $0.model == modelName
        }
        if try database.aiFactsAreCurrent(entityID: document.id,
                                          signature: document.signature, model: modelName) {
            return previous // also caches a successful empty extraction
        }
        let raw = try await ollama.analyzeMemoryEvidence(model: modelName,
            prompt: MemoryRelationCore.factPrompt(document))
        try Task.checkCancellation()
        guard let fresh = try database.evidenceDocument(entityID: document.id),
              fresh.signature == document.signature else { throw CancellationError() }
        let facts = try MemoryRelationCore.parseFacts(raw, for: document,
            model: modelName, createdAt: WorkOSDate.now())
        try database.saveAIFacts(facts, entityID: document.id,
            signature: document.signature, model: modelName)
        inferredMemoryFacts = try database.aiMemoryFacts()
        invalidateMemoryDisplayCaches()
        return facts
    }

    func stopRelationAnalysis() { relationInferenceTask?.cancel() }
}
