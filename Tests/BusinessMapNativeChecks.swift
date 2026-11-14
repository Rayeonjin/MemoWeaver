import AppKit
import SwiftUI

@MainActor enum BusinessMapNativeChecks {
    static func run(model: WorkOSModel, window: NSWindow, host: NSHostingView<some View>) throws {
        let db = model.database!
        func note(_ title: String, _ body: String) throws -> WorkNote {
            let draft = try db.createNote(typeID: "type-note", markdown: true)
            return try db.saveNote(draft, title:title, bodyHTML:body, typeID:draft.typeID,
                bookID:"", noteDate:draft.noteDate, status:draft.status, sourceURL:"",
                pinned:false, archived:false, checkpoint:false)
        }
        let a = try note("R-42 · 고객 요청", "출하 검토\n요청 R-42: 출하 전에 브래킷 간섭을 확인해 주세요.")
        let b = try note("R-42 · 설계 변경 완료", "설계 변경\n요청 R-42에 따라 지지대 형상을 수정하고 검증을 완료했습니다.")
        let c = try note("R-99 · 별개 설비 점검", "설비 C의 브래킷 간섭을 확인해 주세요. 요청 R-99의 별개 업무입니다.")
        let da = try db.evidenceDocument(entityID:"note:"+a.id)!
        let dbb = try db.evidenceDocument(entityID:"note:"+b.id)!
        let raw = #"{"type":"resolves","direction":"BA","summary":"고객 요청 R-42에 대한 형상 변경과 검증 완료 기록입니다.","fromQuote":"요청 R-42에 따라 지지대 형상을 수정하고 검증을 완료했습니다.","toQuote":"요청 R-42: 출하 전에 브래킷 간섭을 확인해 주세요."}"#
        let relation = try MemoryRelationCore.parseRelation(raw,a:da,b:dbb,model:"isolated-fixture",createdAt:WorkOSDate.now())
        try db.saveAIRelation(relation)
        model.inferredMemoryRelations = try db.aiMemoryRelations()
        try model.refresh()
        model.memoryVectors = [a,b,c].map { MemoryVector(id:$0.id,entityID:"note:"+$0.id,
            kind:"note",title:$0.title,signature:"fixture",values:[1,0],fromLine:0,toLine:0) }
        model.selectedNoteID = a.id
        model.selectedPage = .memory
        model.invalidateMemoryDisplayCaches(); model.regenerateMemoryGraph()
        precondition(model.memoryGraph.edges.count == 1)
        precondition(model.memoryGraph.edges[0].inference?.fromID == dbb.id)
        let before = try db.notes().map(\.rawJSON)
        model.openMemoryEvidence(da.id,quote:relation.toQuote)
        UsabilityNativeSmoke.pump()
        precondition(model.selectedPage == .memory && model.selectedNoteID == a.id, "reference stole editor navigation")
        precondition(tryNoteJSON(db) == before, "reference changed source")
        for reader in NSApplication.shared.windows where reader.title.hasPrefix("참고 기록 ·") { reader.orderOut(nil) }
        model.setRelationReview(relation,decision:"irrelevant")
        precondition(model.memoryGraph.edges.isEmpty, "hidden AI relation remains in map")
        model.addConfirmedMemoryLink(da.id,dbb.id,relationKind:"follow_up",memo:"요청 R-42의 설계 변경 후속 확인")
        precondition(model.memoryGraph.edges.count == 1 && model.memoryGraph.edges[0].inference == nil,
                     "manual link must survive AI dismissal without fabricated evidence")
        model.clearRelationReview(relation)
        precondition(model.memoryGraph.edges.count == 1 && model.memoryGraph.edges[0].inference != nil)
        // A source edit invalidates the AI interpretation, not the saved human link.
        _ = try db.saveNote(a,title:a.title,bodyHTML:"요청을 수정했습니다.",typeID:a.typeID,bookID:"",
            noteDate:a.noteDate,status:a.status,sourceURL:"",pinned:false,archived:false,checkpoint:false)
        try model.refresh(); model.regenerateMemoryGraph()
        precondition(model.memoryGraph.edges.count == 1 && model.memoryGraph.edges[0].inference == nil)
        let modified = try db.notes().first { $0.id == a.id }!
        _ = try db.saveNote(modified,title:a.title,bodyHTML:da.text,typeID:a.typeID,bookID:"",
            noteDate:a.noteDate,status:a.status,sourceURL:"",pinned:false,archived:false,checkpoint:false)
        try model.refresh(); model.regenerateMemoryGraph()
        for dark in [false,true] {
            host.appearance = NSAppearance(named:dark ? .darkAqua : .aqua)
            for width: CGFloat in [1000,1400] {
                window.setContentSize(NSSize(width:width,height:930))
                UsabilityNativeSmoke.pump()
                precondition(model.memoryGraph.edges.count == 1 && model.memoryGraph.edges[0].inference != nil,
                             "current source/review refresh must retain checked AI evidence")
            }
        }
        host.appearance = NSAppearance(named:.aqua)
        window.setContentSize(NSSize(width:1400,height:1000))
        UsabilityNativeSmoke.pump()
        print("PASS: native business map, dual evidence/read-only source, hide/restore, manual preservation, stale edit, light/dark at two widths; fixture relations without live inference")
        if let value = ProcessInfo.processInfo.environment["MEMOWEAVER_BUSINESS_MAP_HOLD_SECONDS"], let seconds = Double(value) {
            window.title = "MemoWeaver — business map isolated QA"
            let end = Date().addingTimeInterval(min(600,seconds))
            while window.isVisible && Date() < end { UsabilityNativeSmoke.pump(0.1) }
        }
    }
    private static func tryNoteJSON(_ db: LocalDatabase) -> [String] { (try? db.notes().map(\.rawJSON)) ?? [] }
}
