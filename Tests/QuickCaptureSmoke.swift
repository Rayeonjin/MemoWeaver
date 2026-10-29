import Foundation

@main
struct QuickCaptureSmoke {
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkOSQuickCaptureSmoke-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let db = try LocalDatabase(directoryOverride: directory)
        let day = "2026-10-19"
        let empty = try db.saveQuickCapture(existing: nil, day: day, text: "")
        assert(empty == nil, "Do not create empty daily note when simply opening app")
        let firstNotes = try db.notes()
        assert(firstNotes.isEmpty)
        let text = "[09:30] API <timeout> & 오류\n회의에서 **중요**한 점\n한글 😀 & \\\"quote\\\"\n"
        let one = try db.saveQuickCapture(existing: nil, day: day, text: text)!
        assert(WorkOSQuickCapture.isDailyNote(one, day: day))
        assert(one.title == WorkOSQuickCapture.title(for: day))
        assert(one.bodyHTML.contains("&lt;timeout&gt;"))
        assert(!one.bodyHTML.contains("<timeout>"))
        assert(WorkOSQuickCapture.plainText(one) == text, "Unicode and trailing newline preserved")
        assert(WorkOSQuickCapture.isPlainCapture(one))
        assert(one.revisions.count == 1)
        let same = try db.saveQuickCapture(existing: one, day: day, text: text)!
        assert(same.id == one.id && same.revisions.count == 1)
        let altered = try db.saveQuickCapture(existing: same, day: day, text: text + "새 작업 기록")!
        assert(altered.id == one.id && altered.plainBody.contains("새 작업"))
        let allNotes = try db.notes()
        assert(allNotes.count == 1, "Repeated autosaves must not create extra notes")
        let backup = try db.exportBrowserCompatibleJSON()
        let exported = try JSONSerialization.jsonObject(with: backup) as! [String: Any]
        let notes = exported["notes"] as! [[String: Any]]
        assert(notes.count == 1 && notes[0]["quickCaptureDay"] as? String == day)
        let reopen = try LocalDatabase(directoryOverride: directory)
        let restored = try reopen.notes().first!
        assert(WorkOSQuickCapture.plainText(restored) == text + "새 작업 기록")
        assert(WorkOSQuickCapture.isPlainCapture(restored))
        // Once someone adds rich formatting, quick mode MUST NOT replace their HTML.
        let rich = try db.saveNote(restored, title: restored.title,
            bodyHTML: "<p><b>보존할 굵은 텍스트</b></p>", typeID: restored.typeID,
            bookID: restored.bookID, noteDate: restored.noteDate, status: restored.status,
            sourceURL: restored.sourceURL, pinned: restored.pinned, archived: restored.archived,
            checkpoint: true)
        assert(!WorkOSQuickCapture.isPlainCapture(rich))
        do {
            _ = try db.saveQuickCapture(existing: rich, day: day, text: "덮어쓰기")
            assertionFailure("Rich text overwrite must be rejected")
        } catch { }
        let afterRejectedOverwrite = try db.notes()
        assert(afterRejectedOverwrite.first!.bodyHTML.contains("<b>보존할 굵은 텍스트</b>"))
        print("PASS quick capture: lazy creation, UTF-8 roundtrip, autosave, revision, backup/reopen, rich overwrite guard")
    }
}
