import Foundation

@main
struct RelationMemorySmoke {
    static func main() throws {
        let date = "2026-10-23T21:00:00+09:00"
        let a = MemoryEvidenceDocument(id: "note:a", title: "기존 현상",
            text: "오전 거래량이 급증했다. 원인을 확인할 필요가 있다.")
        let b = MemoryEvidenceDocument(id: "note:b", title: "후속 확인",
            text: "이전에 확인한 거래량 급증 현상을 재검토했다. 배치 시간과 겹쳤다.")
        let factsJSON = #"{"items":[{"kind":"problem","summary":"거래량 급증 원인 미확인","quote":"원인을 확인할 필요가 있다.","dateHint":""}]}"#
        let facts = try MemoryRelationCore.parseFacts(factsJSON, for: a, model: "test", createdAt: date)
        assert(facts.count == 1 && facts[0].quote == "원인을 확인할 필요가 있다.")
        let emptyFacts = try MemoryRelationCore.parseFacts(#"{"items":[]}"#, for: a, model: "test", createdAt: date)
        assert(emptyFacts.isEmpty)
        func rejected(_ operation: () throws -> Void) -> Bool {
            do { try operation(); return false } catch { return true }
        }
        assert(rejected { _ = try MemoryRelationCore.parseFacts(#"{"items":[{"kind":"problem","summary":"허구","quote":"이 문장은 없다","dateHint":""}]}"#, for: a, model: "test", createdAt: date) })
        assert(rejected { _ = try MemoryRelationCore.parseFacts(#"{"items":[{"kind":"unknown","summary":"설명","quote":"원인을 확인할 필요가 있다.","dateHint":""}]}"#, for: a, model: "test", createdAt: date) })
        assert(rejected { _ = try MemoryRelationCore.parseFacts(#"{"items":[{"kind":"problem","summary":"원인","quote":"원인을 확인할 필요가 있다.","dateHint":"2024"}]}"#, for: a, model: "test", createdAt: date) })
        let relationJSON = #"{"type":"follow_up","direction":"AB","summary":"과거 현상에 대한 후속 조사이다","fromQuote":"오전 거래량이 급증했다.","toQuote":"이전에 확인한 거래량 급증 현상을 재검토했다."}"#
        let relation = try MemoryRelationCore.parseRelation(relationJSON, a: a, b: b, model: "test", createdAt: date)
        assert(relation.hasRelationship && relation.typeLabel == "후속 기록" && relation.id == MemoryRelationCore.pairKey(a.id, b.id))
        assert(MemoryRelationCore.relevant(to: a.id, relationships: [relation], signatures: [a.id: a.signature, b.id: b.signature]).count == 1)
        assert(MemoryRelationCore.relevant(to: a.id, relationships: [relation], signatures: [a.id: "edited", b.id: b.signature]).isEmpty)
        assert(rejected { _ = try MemoryRelationCore.parseRelation(#"{"type":"resolves","direction":"AB","summary":"허위 해결 주장","fromQuote":"실제로 없는 문장이다","toQuote":"이전에 확인한 거래량 급증 현상을 재검토했다."}"#, a: a, b: b, model: "test", createdAt: date) })
        assert(rejected { _ = try MemoryRelationCore.parseRelation("```json\n" + relationJSON + "\n```", a: a, b: b, model: "test", createdAt: date) })
        let reverse = try MemoryRelationCore.parseRelation(#"{"type":"changes","direction":"BA","summary":"추후 판단 변경","fromQuote":"배치 시간과 겹쳤다.","toQuote":"원인을 확인할 필요가 있다."}"#, a: a, b: b, model: "test", createdAt: date)
        assert(reverse.fromID == b.id && reverse.toID == a.id && reverse.id == relation.id)
        let none = try MemoryRelationCore.parseRelation(#"{"type":"none","direction":"AB","summary":"","fromQuote":"","toQuote":""}"#, a: a, b: b, model: "test", createdAt: date)
        assert(!none.hasRelationship && none.id == relation.id)
        assert(MemoryRelationCore.keywordOverlap("거래량 급증 위험", "거래량", candidate: "급증 원인", candidateTitle: "과거 거래량") > 0)
        // Exercise the same lexical ranking used by the macOS WorkOSModel
        // entry point, using only Foundation test dependencies.
        let sampleNotes: [WorkNote] = [
            .from(["id": "active", "title": "과거 거래량", "body": "거래량 급증 원인", "bodyFormat": "markdown"]),
            .from(["id": "deleted", "title": "거래량 급증", "body": "거래량 급증", "bodyFormat": "markdown", "deletedAt": date]),
            .from(["id": "unrelated", "title": "점심 식사", "body": "저녁 약속", "bodyFormat": "markdown"])
        ]
        let lexicalCenter = MemoryEvidenceDocument(id: "note:active", title: "거래량 급증",
            text: "거래량 급증 원인 재검토")
        let lexicalNotes = MemoryRelationCore.lexicalCandidateIDs(center: lexicalCenter,
            notes: sampleNotes, virtualMemories: [], archives: [])
        assert(!lexicalNotes.contains("note:active"))
        assert(!lexicalNotes.contains("note:deleted"))
        assert(!lexicalNotes.contains("note:unrelated"))
        let secondCenter = MemoryEvidenceDocument(id: "note:focus", title: "거래량 급증",
            text: "거래량 급증 원인 재검토")
        let lexicalRanks = MemoryRelationCore.lexicalCandidateIDs(center: secondCenter,
            notes: sampleNotes, virtualMemories: [], archives: [])
        assert(lexicalRanks == ["note:active"])
        let legacySegments = [
            VirtualMemory(id: "v1", sourceKind: "note", sourceID: "n10k", sourceSignature: "x",
                fromLine: 1, toLine: 100, title: "A", category: "record", aiReviewed: false, createdAt: date),
            VirtualMemory(id: "v2", sourceKind: "note", sourceID: "n10k", sourceSignature: "x",
                fromLine: 101, toLine: 200, title: "B", category: "record", aiReviewed: false, createdAt: date)
        ]
        assert(MemoryRelationCore.shouldConsider(centerID: "virtual:v1", candidateID: "virtual:v2", virtualMemories: legacySegments))
        assert(!MemoryRelationCore.shouldConsider(centerID: "virtual:v1", candidateID: "note:n10k", virtualMemories: legacySegments))
        assert(!MemoryRelationCore.shouldConsider(centerID: "note:n10k", candidateID: "virtual:v1", virtualMemories: legacySegments))


        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MWRelation-" + UUID().uuidString)
        let root2 = FileManager.default.temporaryDirectory.appendingPathComponent("MWRelationRestore-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: root2) }
        let db = try LocalDatabase(directoryOverride: root)
        let rawA = try db.createNote(typeID: "type-note", markdown: true)
        let rawB = try db.createNote(typeID: "type-note", markdown: true)
        let aNote = try db.saveNote(rawA, title: "기존 현상", bodyHTML: a.text,
            typeID: rawA.typeID, bookID: "", noteDate: "2024-01-01", status: "진행 중",
            sourceURL: "", pinned: false, archived: false, checkpoint: false)
        let bNote = try db.saveNote(rawB, title: "후속 확인", bodyHTML: b.text,
            typeID: rawB.typeID, bookID: "", noteDate: "2025-01-01", status: "진행 중",
            sourceURL: "", pinned: false, archived: false, checkpoint: false)
        guard let documentA = try db.evidenceDocument(entityID: "note:" + aNote.id),
              let documentB = try db.evidenceDocument(entityID: "note:" + bNote.id) else { fatalError("stored evidence not found") }
        let savedFact = try MemoryRelationCore.parseFacts(factsJSON, for: documentA, model: "test", createdAt: date)
        try db.saveAIFacts(savedFact, entityID: documentA.id, signature: documentA.signature, model: "test")
        let factsAfter49 = try db.aiMemoryFacts()
        assert(factsAfter49.count == 1, "Fact storage remains unchanged after invalid batch")
        assert(rejected { try db.saveAIFacts(facts, entityID: documentA.id, signature: documentA.signature, model: "test") })
        let factsAfter51 = try db.aiMemoryFacts()
        assert(factsAfter51.count == 1, "Fact storage remains unchanged after invalid batch")
        let factRunA = try db.aiFactsAreCurrent(entityID: documentA.id, signature: documentA.signature, model: "test")
        assert(factRunA)
        try db.saveAIFacts([], entityID: documentB.id, signature: documentB.signature, model: "test")
        let factRunB = try db.aiFactsAreCurrent(entityID: documentB.id, signature: documentB.signature, model: "test")
        assert(factRunB)
        let allFacts = try db.aiMemoryFacts()
        assert(!allFacts.contains { $0.entityID == documentB.id })
        let storedRelation = try MemoryRelationCore.parseRelation(relationJSON, a: documentA, b: documentB, model: "test", createdAt: date)
        try db.saveAIRelation(storedRelation)
        try db.saveAIRelation(storedRelation) // idempotent pair key
        let relationsAfter55 = try db.aiMemoryRelations()
        assert(relationsAfter55.count == 1)
        let backup = try db.exportBrowserCompatibleJSON()
        let decoded = try JSONSerialization.jsonObject(with: backup) as! [String: Any]
        assert((decoded["aiMemoryFacts"] as? [Any])?.count == 1)
        assert((decoded["aiMemoryRelations"] as? [Any])?.count == 1)
        let restored = try LocalDatabase(directoryOverride: root2)
        _ = try restored.importBrowserBackup(backup)
        let restoredFacts = try restored.aiMemoryFacts()
        assert(restoredFacts.count == 1)
        let restoredRelations = try restored.aiMemoryRelations()
        assert(restoredRelations.count == 1)
        // Tampered backup quotes must NOT import inferred edges.
        let root3 = FileManager.default.temporaryDirectory.appendingPathComponent("MWTamper-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root3) }
        let tamperedDB = try LocalDatabase(directoryOverride: root3)
        var bad = decoded
        if var rows = bad["aiMemoryRelations"] as? [[String: Any]], !rows.isEmpty {
            rows[0]["fromQuote"] = "꾸며낸 원문 근거"
            bad["aiMemoryRelations"] = rows
        }
        _ = try tamperedDB.importBrowserBackup(try JSONSerialization.data(withJSONObject: bad))
        let tamperedRelations = try tamperedDB.aiMemoryRelations()
        assert(tamperedRelations.isEmpty)
        // Editing the original is non-destructive; old AI results become stale.
        _ = try db.saveNote(aNote, title: "수정된 현상", bodyHTML: "내용이 변경되었다.",
            typeID: aNote.typeID, bookID: "", noteDate: aNote.noteDate, status: aNote.status,
            sourceURL: "", pinned: false, archived: false, checkpoint: false)
        let changed = try db.evidenceDocument(entityID: documentA.id)!
        assert(!MemoryRelationCore.isCurrent(storedRelation, signatures: [documentA.id: changed.signature, documentB.id: documentB.signature]))
        let relationsAfter81 = try db.aiMemoryRelations()
        assert(relationsAfter81.count == 1)
        print("PASS AI relation: exact quotations, hallucination/JSON rejection, direction, cache, SQLite, tamper-proof import, stale edit")
    }
}
