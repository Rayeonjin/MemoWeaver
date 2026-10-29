import Foundation

@main
struct MultiCaptureSmoke {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MemoryHome-MultiCapture-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let db = try LocalDatabase(directoryOverride: root)
        let today = "2026-10-19"
        let first = try db.createQuickCaptureNote(day: today)
        let second = try db.createQuickCaptureNote(day: today)
        assert(first.id != second.id, "Each new quick note must have a unique ID")
        assert(WorkOSQuickCapture.isNewCapture(first))
        assert(!WorkOSQuickCapture.isDailyNote(first, day: today), "New capture must not be mistaken for the legacy daily document")
        assert(WorkOSQuickCapture.isCapture(first))
        assert(WorkOSQuickCapture.isEmptyNewCapture(first, day: today))
        assert(first.title.isEmpty && first.noteDate == today)
        assert(first.visibleTitle == "새 빠른 기록")

        let firstHTML = "<p><strong>장애 대응</strong> API 지연 원인 검토</p><p>점검: 한글 😀</p>"
        let rich = try db.saveNote(first, title: "", bodyHTML: firstHTML,
            typeID: "type-note", bookID: "", noteDate: today, status: "진행 중",
            sourceURL: "", pinned: false, archived: false, checkpoint: false)
        assert(rich.id == first.id && rich.revisions.count == 1)
        assert(rich.bodyHTML.contains("<strong>"), "Rich HTML formatting must not be lost")
        assert(!WorkOSQuickCapture.isEmptyNewCapture(rich, day: today))
        assert(rich.visibleTitle.contains("장애 대응"), "First body line becomes an inferred display title")

        let secondHTML = "<h2>회의 검토</h2><p>일정과 후속 조치를 논의했다.</p>"
        let savedSecond = try db.saveNote(second, title: "", bodyHTML: secondHTML,
            typeID: "type-note", bookID: "", noteDate: today, status: "진행 중",
            sourceURL: "", pinned: false, archived: false, checkpoint: false)
        let updatedFirst = try db.saveNote(rich, title: "장애 로그", bodyHTML: rich.bodyHTML,
            typeID: rich.typeID, bookID: "", noteDate: today, status: "진행 중",
            sourceURL: "", pinned: false, archived: false, checkpoint: true)
        assert(updatedFirst.visibleTitle == "장애 로그", "Explicit title overrides inferred one")
        assert(savedSecond.bodyHTML.contains("회의 검토"))
        let storage = try db.notes()
        assert(storage.count == 2 && storage.map(\.id).contains(first.id) && storage.map(\.id).contains(second.id))
        assert(storage.first { $0.id == second.id }?.bodyHTML == secondHTML, "Independent notes cannot overwrite one another")

        let blocks = [WorkBlock.make(.table)]
        let withBlock = try db.saveBlocks(savedSecond, blocks: blocks, checkpoint: true)
        assert(withBlock.workosBlocks.count == 1, "Table blocks can be used in quick mode")
        assert(WorkOSQuickCapture.isNewCapture(withBlock))
        let archiveDay = "2026-10-18"
        let legacy = try db.saveQuickCapture(existing: nil, day: archiveDay, text: "이전 일일 기록\n그대로 보존")!
        assert(WorkOSQuickCapture.isCapture(legacy))
        assert(!WorkOSQuickCapture.isNewCapture(legacy))

        let exported = try db.exportBrowserCompatibleJSON()
        let reopened = try LocalDatabase(directoryOverride: root)
        let restored = try reopened.notes()
        assert(restored.count == 3)
        assert(restored.first { $0.id == second.id }?.workosBlocks.count == 1)
        assert(restored.first { $0.id == legacy.id }?.plainBody.contains("그대로 보존") == true)
        assert(restored.first { $0.id == first.id }?.visibleTitle == "장애 로그")
        let otherRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MemoryHome-MultiCapture-Import-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: otherRoot) }
        let secondDB = try LocalDatabase(directoryOverride: otherRoot)
        let counts = try secondDB.importBrowserBackup(exported)
        assert(counts.notes == 3)
        let reimported = try secondDB.notes()
        assert(reimported.first(where: { $0.id == second.id })?.workosBlocks.count == 1)
        assert(reimported.first(where: { $0.id == first.id })?.visibleTitle == "장애 로그")

        let related = WorkOSSearch.find(question: "장애 API 지연", notes: restored, chunks: [])
        assert(related.contains(where: { $0.sourceID == first.id }), "Quick notes participate in full text search")
        print("PASS multi capture: independent notes, rich HTML, first-line titles, category-compatible raw JSON, blocks, legacy daily, JSON backup/import, search")
    }
}
