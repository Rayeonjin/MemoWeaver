import AppKit
import SwiftUI

// Optional, separately bundled QA preview. It never opens the live database or
// real preferences. Run only with MEMOWEAVER_FORCE_PREVIEW=1 on the test binary.
@MainActor enum D3ForcePreview {
    final class Delegate: NSObject, NSWindowDelegate {
        @objc func quit() { NSApplication.shared.stop(nil) }
        func windowWillClose(_ notification: Notification) { quit() }
    }
    static func run() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mw-force-preview-" + UUID().uuidString)
        let suite = "mw-force-preview-" + UUID().uuidString
        let defaults = UserDefaults(suiteName:suite)!
        defaults.set("manual",forKey:MemoryIdlePolicy.defaultsKey)
        defer { defaults.removePersistentDomain(forName:suite); try? FileManager.default.removeItem(at:root) }
        let model = WorkOSModel(directoryOverride:root,seedWelcome:false,preferences:defaults)
        let db = model.database!
        func note(_ title: String, _ text: String) throws -> WorkNote {
            let n = try db.createNote(typeID:"type-note",markdown:true)
            return try db.saveNote(n,title:title,bodyHTML:text,typeID:n.typeID,bookID:"",noteDate:n.noteDate,
                status:n.status,sourceURL:"",pinned:false,archived:false,checkpoint:false)
        }
        let a = try note("R-42 · 고객 요청","요청 R-42: 출하 전에 브래킷 간섭을 확인해 주세요.")
        let b = try note("R-42 · 설계 변경","요청 R-42에 따라 지지대 형상을 변경했습니다.")
        let c = try note("R-42 · 검증 완료","요청 R-42의 변경 형상을 시험하고 출하 가능함을 확인했습니다.")
        let d = try note("R-17 · 설비 이상","설비 R-17의 베어링 진동이 증가해 점검을 요청했습니다.")
        let e = try note("R-17 · 수리 조치","설비 R-17의 마모된 베어링 교체 후 정상 작동을 확인했습니다.")
        _ = try note("다음 주 준비","예비 부품 수량과 작업 일정을 확인합니다. 독립된 참고 메모입니다.")
        func relation(_ from: WorkNote, _ to: WorkNote, _ kind: String, _ summary: String) throws {
            let aa = try db.evidenceDocument(entityID:"note:"+from.id)!
            let bb = try db.evidenceDocument(entityID:"note:"+to.id)!
            let raw = try JSONSerialization.data(withJSONObject:["type":kind,"direction":"AB","summary":summary,"fromQuote":aa.text,"toQuote":bb.text])
            let r = try MemoryRelationCore.parseRelation(String(decoding:raw,as:UTF8.self),a:aa,b:bb,model:"synthetic-qa",createdAt:WorkOSDate.now())
            try db.saveAIRelation(r)
        }
        try relation(b,a,"resolves","고객 요청 R-42를 반영한 형상 변경 기록입니다.")
        try relation(b,c,"follow_up","변경한 R-42 형상에 대해 시험과 출하 검증을 이어갔습니다.")
        try relation(c,a,"supports","R-42 시험 결과가 고객 요청의 출하 판단을 뒷받침합니다.")
        try relation(e,d,"resolves","R-17의 진동 문제를 베어링 교체로 조치한 기록입니다.")
        try db.addMemoryLink(MemoryLink("note:"+a.id,"note:"+c.id,relationKind:"supports",memo:"R-42 출하 판단의 시험 근거"))
        try model.refresh()
        model.inferredMemoryRelations = try db.aiMemoryRelations()
        model.confirmedMemoryLinks = try db.confirmedLinks()
        model.selectedNoteID = a.id; model.selectedPage = .memory
        model.regenerateMemoryGraph()
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = Delegate()
        let menu = NSMenu(), appItem = NSMenuItem(), appMenu = NSMenu()
        let quit = NSMenuItem(title:"QA 종료",action:#selector(Delegate.quit),keyEquivalent:"q")
        quit.target = delegate; appMenu.addItem(quit); appItem.submenu = appMenu; menu.addItem(appItem); app.mainMenu = menu
        let window = NSWindow(contentRect:NSRect(x:80,y:80,width:1360,height:1000),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        window.title = "MemoWeaver Graph QA — 격리된 예시 데이터"
        window.isReleasedWhenClosed = false; window.delegate = delegate
        window.contentView = NSHostingView(rootView:WorkOSMainView().environmentObject(model).defaultAppStorage(defaults))
        window.makeKeyAndOrderFront(nil); app.activate(ignoringOtherApps:true)
        print("READY: isolated force-map preview; no live notes/preferences")
        app.run()
        window.orderOut(nil)
    }
}
