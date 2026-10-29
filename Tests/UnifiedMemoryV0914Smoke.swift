import Foundation

@main
struct UnifiedMemoryV0914Smoke {
    static func main() throws {
        let date = "2026-10-24T10:00:00+09:00"
        let sourceA = MemoryEvidenceDocument(id: "note:a", title: "첫 기록", text:
            "이전 배치 작업에서 거래량 급증을 관찰했다. 원인은 아직 확인하지 못했다.")
        let sourceB = MemoryEvidenceDocument(id: "note:b", title: "후속 분석", text:
            "거래량 급증 관련 배치 시간대를 조사했다. 변경을 검토했다.")
        let sourceC = MemoryEvidenceDocument(id: "note:c", title: "관찰 결과", text:
            "배치 시각 변경 후 이전 거래량 급증 현상이 재발하는지 확인했다.")
        let jsonAB = #"{"type":"follow_up","direction":"AB","summary":"배치 관련 후속 검토","fromQuote":"이전 배치 작업에서 거래량 급증을 관찰했다.","toQuote":"거래량 급증 관련 배치 시간대를 조사했다."}"#
        let jsonBC = #"{"type":"changes","direction":"AB","summary":"작업 변경 후 관찰","fromQuote":"변경을 검토했다.","toQuote":"배치 시각 변경 후 이전 거래량 급증 현상이 재발하는지 확인했다."}"#
        let ab = try MemoryRelationCore.parseRelation(jsonAB, a: sourceA, b: sourceB, model: "local", createdAt: date)
        let bc = try MemoryRelationCore.parseRelation(jsonBC, a: sourceB, b: sourceC, model: "local", createdAt: date)
        let routes = MemoryTimelineCore.routes(focus: sourceA.id, relations: [ab,bc])
        assert(routes.first?.relationships.count == 2)
        let reverse = MemoryTimelineCore.routes(focus: sourceC.id, relations: [ab,bc])
        assert(reverse.first?.relationships.count == 2)
        let badLoop = MemoryTimelineCore.routes(focus: sourceA.id, relations: [ab,bc,
            MemoryInferredRelation(fromID: "note:c", toID: "note:a", relationType: "follow_up",
                summary: "가상 루프", fromQuote: "a", toQuote: "b", fromSignature: "x",
                toSignature: "y", model: "local", createdAt: date)])
        assert(badLoop.allSatisfy { Set($0.entities).count == $0.entities.count })
        let issue = MemoryFact(entityID: sourceA.id, sourceSignature: sourceA.signature,
            ordinal: 0, kind: "problem", summary: "원인 확인 필요", quote: "원인은 아직 확인하지 못했다.",
            dateHint: "", model: "local", createdAt: date)
        assert(MemoryTimelineCore.noFollowUpFound(for: sourceA.id, facts: [issue], relations: []).count == 1)
        assert(MemoryTimelineCore.noFollowUpFound(for: sourceA.id, facts: [issue], relations: [ab]).isEmpty)
        let review = MemoryRelationReview(pairKey: ab.id, fromSignature: ab.fromSignature,
            toSignature: ab.toSignature, decision: "irrelevant", createdAt: date)
        assert(review.applies(to: ab))
        assert(!MemoryRelationReview(pairKey: ab.id, fromSignature: "edited", toSignature: ab.toSignature,
            decision: "irrelevant", createdAt: date).applies(to: ab))
        let lines = MemoryReferenceCore.lineExcerpt("a\nb\nc\nd\ne", from: 3, to: 3, padding: 1)
        assert(lines == "2  b\n3  c\n4  d")
        assert(MemoryReferenceCore.lineExcerpt("a\nb", from: 0, to: 0) == "a\nb")

        let one = FileManager.default.temporaryDirectory.appendingPathComponent("MW-0914-" + UUID().uuidString)
        let two = FileManager.default.temporaryDirectory.appendingPathComponent("MW-0914-B-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: one); try? FileManager.default.removeItem(at: two) }
        let db = try LocalDatabase(directoryOverride: one)
        let noteA = try db.createNote(typeID: "type-note", markdown: true)
        let noteB = try db.createNote(typeID: "type-note", markdown: true)
        let actualA = try db.saveNote(noteA, title: "첫 기록", bodyHTML: sourceA.text,
            typeID: noteA.typeID, bookID: "", noteDate: "2024-01-01", status: "진행 중",
            sourceURL: "", pinned: false, archived: false, checkpoint: false)
        let actualB = try db.saveNote(noteB, title: "후속 분석", bodyHTML: sourceB.text,
            typeID: noteB.typeID, bookID: "", noteDate: "2024-02-01", status: "진행 중",
            sourceURL: "", pinned: false, archived: false, checkpoint: false)
        let docA = try db.evidenceDocument(entityID: "note:" + actualA.id)!
        let docB = try db.evidenceDocument(entityID: "note:" + actualB.id)!
        let actualRel = try MemoryRelationCore.parseRelation(jsonAB, a: docA, b: docB,
            model: "local", createdAt: date)
        try db.saveAIRelation(actualRel)
        let persisted = MemoryRelationReview(pairKey: actualRel.id,
            fromSignature: actualRel.fromSignature, toSignature: actualRel.toSignature,
            decision: "irrelevant", createdAt: date)
        try db.saveMemoryRelationReview(persisted)
        let reviewCount = try db.memoryRelationReviews().count
        assert(reviewCount == 1)
        let backup = try db.exportBrowserCompatibleJSON()
        let data = try JSONSerialization.jsonObject(with: backup) as! [String: Any]
        assert((data["memoryRelationReviews"] as? [[String: Any]])?.count == 1)
        let imported = try LocalDatabase(directoryOverride: two)
        _ = try imported.importBrowserBackup(backup)
        let restored = try imported.memoryRelationReviews()
        assert(restored.count == 1 && restored[0].applies(to: actualRel))
        try imported.deleteMemoryRelationReview(persisted.id)
        let noReviews = try imported.memoryRelationReviews().isEmpty
        assert(noReviews)
        // A forged review cannot survive import without its validated relation.
        var changed = data
        var tampered = (changed["memoryRelationReviews"] as? [[String: Any]]) ?? []
        tampered[0]["pairKey"] = "note:fake|note:fake2"
        changed["memoryRelationReviews"] = tampered
        let other = try LocalDatabase(directoryOverride: one.appendingPathComponent("tampered"))
        _ = try other.importBrowserBackup(try JSONSerialization.data(withJSONObject: changed))
        let tamperedAbsent = try other.memoryRelationReviews().isEmpty
        assert(tamperedAbsent)
        print("PASS 0.9.14 unified memory: directed trails/cycles, unresolved wording, snapshot excerpts, feedback revisions, SQLite and JSON restoration")
    }
}
