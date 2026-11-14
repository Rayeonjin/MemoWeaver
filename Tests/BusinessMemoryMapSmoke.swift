import Foundation

@main struct BusinessMemoryMapSmoke {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mw-business-map-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let db = try LocalDatabase(directoryOverride: root)
        func note(_ title: String, _ body: String) throws -> WorkNote {
            let draft = try db.createNote(typeID: "type-note", markdown: true)
            return try db.saveNote(draft, title: title, bodyHTML: body,
                typeID: draft.typeID, bookID: "", noteDate: draft.noteDate, status: draft.status,
                sourceURL: "", pinned: false, archived: false, checkpoint: false)
        }
        let a = try note("R-42 고객 요청", "요청 R-42: 출하 전에 브래킷 간섭을 확인해 주세요.")
        let b = try note("형상 변경 완료", "요청 R-42에 따라 지지대 형상을 수정하고 검증을 완료했습니다.")
        let c = try note("별개 설비 점검", "설비 C의 브래킷 간섭을 확인해 주세요. 요청 R-99의 별도 업무입니다.")
        let notes = [a,b,c]
        let vectors = notes.map { MemoryVector(id: $0.id, entityID: "note:" + $0.id,
            kind: "note", title: $0.title, signature: "test", values: [1,0], fromLine: 0, toLine: 0) }
        func graph(_ relations: [MemoryInferredRelation] = [], _ links: [MemoryLink] = [], _ threshold: Double = 0.45) -> MemoryGraphData {
            MemoryEngine.graph(notes: notes, archives: [], vectors: vectors,
                confirmed: links, inferred: relations, threshold: threshold)
        }
        precondition(graph().edges.isEmpty, "identical embeddings must not create business links")
        precondition(graph([], [], 0.88).edges.isEmpty, "threshold must not alter business relationships")
        let da = try db.evidenceDocument(entityID: "note:" + a.id)!
        let dbb = try db.evidenceDocument(entityID: "note:" + b.id)!
        let docs = [da.id:da, dbb.id:dbb]
        let json = #"{"type":"resolves","direction":"BA","summary":"요청 R-42의 형상 변경 및 검증 완료 기록","fromQuote":"요청 R-42에 따라 지지대 형상을 수정하고 검증을 완료했습니다.","toQuote":"요청 R-42: 출하 전에 브래킷 간섭을 확인해 주세요."}"#
        let relation = try MemoryRelationCore.parseRelation(json, a:da, b:dbb, model:"fixture", createdAt:WorkOSDate.now())
        precondition(MemoryRelationCore.isGrounded(relation, documents:docs))
        let result = graph([relation])
        precondition(result.edges.count == 1 && result.edges[0].first == dbb.id, "preserve business direction")
        precondition(result.edges[0].inference?.fromQuote == relation.fromQuote, "both source quotes retained")
        precondition(!result.edges.contains { $0.first == "note:"+c.id || $0.second == "note:"+c.id }, "similar separate incident stays unconnected")
        let manual = MemoryLink(da.id,dbb.id,relationKind:"follow_up",memo:"고객 요청 후속 검토")
        let combined = graph([relation],[manual])
        precondition(combined.edges.count == 1 && combined.edges[0].confirmed)
        precondition(combined.edges[0].inference?.id == relation.id && combined.edges[0].manualMemo == manual.memo, "confirmation must retain independent evidence")
        let noAI = graph([], [manual])
        precondition(noAI.edges[0].inference == nil && noAI.edges[0].confirmed, "manual connection must not fabricate AI evidence")
        let changed = MemoryEvidenceDocument(id:da.id,title:da.title,text:"업무 내용을 수정했습니다.")
        precondition(!MemoryRelationCore.isGrounded(relation,documents:[da.id:changed,dbb.id:dbb]), "source edit invalidates old evidence")
        var forged = docs
        forged[da.id] = MemoryEvidenceDocument(id:da.id,title:da.title,text:"")
        precondition(!MemoryRelationCore.isGrounded(relation,documents:forged))
        let none = try MemoryRelationCore.parseRelation(#"{"type":"none","direction":"AB","summary":"","fromQuote":"","toQuote":""}"#,a:da,b:dbb,model:"fixture",createdAt:WorkOSDate.now())
        precondition(graph([none]).edges.isEmpty)
        try db.saveAIRelation(relation)
        try db.addMemoryLink(manual)
        let backup = try db.exportBrowserCompatibleJSON()
        let restoreRoot = root.appendingPathComponent("restore")
        let restored = try LocalDatabase(directoryOverride:restoreRoot)
        _ = try restored.importBrowserBackup(backup)
        let restoredAI = try restored.aiMemoryRelations(), restoredManual = try restored.confirmedLinks()
        precondition(restoredAI.count == 1 && restoredManual.first?.memo == manual.memo)
        let remaining = try db.notes(); precondition(remaining.count == 3, "inspection does not edit originals")
        print("PASS: no similarity edges, typed business relation/direction, both quotes, manual/evidence coexistence, stale rejection, negative relation and JSON roundtrip")
    }
}
