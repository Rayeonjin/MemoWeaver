import Foundation

@main
struct UXConsolidationSmoke {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MemoryHome-UX-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let db = try LocalDatabase(directoryOverride: root)
        let today = WorkOSDate.day()

        // Retired "archived" notes return to the ordinary list without new IDs or revisions.
        let original = try db.createNote(typeID: "type-meeting")
        let archived = try db.saveNote(original, title: "이전 보관 회의록",
            bodyHTML: "<h2>원문</h2><p>중요한 한글 기록</p>", typeID: "type-meeting",
            bookID: "", noteDate: "2025-03-01", status: "완료", sourceURL: "https://example.invalid",
            pinned: true, archived: true, checkpoint: true)
        let archivedOriginalJSON = WorkOSJSON.dictionary(archived.rawJSON)
        let comparison = try db.createNote(typeID: "type-note")
        let normal = try db.saveNote(comparison, title: "오늘의 보통 메모", bodyHTML: "<p>평범한 기록</p>",
            typeID: "type-note", bookID: "", noteDate: today, status: "진행 중",
            sourceURL: "", pinned: false, archived: false, checkpoint: false)
        let deleted = try db.createNote(typeID: "type-note")
        let trashed = try db.updateDeleted(deleted, delete: true)
        let before = try db.notes()
        assert(before.contains(where: { $0.id == archived.id && $0.archived }))
        assert(NotesListFilter.matches(archived, scope: .all), "Legacy archived note must be visible even before migration")

        let restoredCount = try db.restoreLegacyArchivedNotesSafely()
        assert(restoredCount == 1, "Exactly the formerly archived note is restored")
        let recovered = try db.notes().first(where: { $0.id == archived.id })!
        assert(!recovered.archived)
        var expected = archivedOriginalJSON
        expected["archived"] = false
        let expectedJSON = try WorkOSJSON.encode(expected)
        assert(recovered.rawJSON == expectedJSON, "Only retired flag may change")
        assert(recovered.createdAt == archived.createdAt && recovered.updatedAt == archived.updatedAt)
        assert(recovered.revisions.count == archived.revisions.count && recovered.revisions.count == 1)
        assert(recovered.bodyHTML == archived.bodyHTML && recovered.noteDate == archived.noteDate)
        assert(recovered.sourceURL == archived.sourceURL && recovered.pinned)
        let backupFolder = root.appendingPathComponent("Backups")
        let initialBackups = try FileManager.default.contentsOfDirectory(atPath: backupFolder.path)
            .filter { $0.hasSuffix(".sqlite") }
        assert(!initialBackups.isEmpty, "Migration must make a pre-change SQLite backup")
        let repeatedMigrationCount = try db.restoreLegacyArchivedNotesSafely()
        assert(repeatedMigrationCount == 0, "Migration is idempotent")
        let afterBackups = try FileManager.default.contentsOfDirectory(atPath: backupFolder.path)
            .filter { $0.hasSuffix(".sqlite") }
        assert(afterBackups.count == initialBackups.count, "Second migration must not create another backup")

        // One filter engine for notes, regardless of legacy capture origin or archive status.
        let allNotes = try db.notes()
        let activeNotes = allNotes.filter { NotesListFilter.matches($0, scope: .all) }
        assert(activeNotes.count == 2, "All nondeleted notes are in one list")
        assert(activeNotes.contains(where: { $0.id == recovered.id }))
        assert(!activeNotes.contains(where: { $0.id == deleted.id }))
        assert(NotesListFilter.matches(normal, scope: .today, today: today))
        assert(NotesListFilter.matches(recovered, scope: .today, today: today), "Today includes a past note edited today")
        var oldRaw = WorkOSJSON.dictionary(recovered.rawJSON)
        oldRaw["updatedAt"] = "2025-03-02T10:00:00.000Z"
        let olderNote = WorkNote.from(oldRaw)
        assert(!NotesListFilter.matches(olderNote, scope: .today, today: today))
        assert(!NotesListFilter.matches(olderNote, scope: .recent, recentStart: "2026-10-01"))
        assert(NotesListFilter.matches(recovered, scope: .pinned))
        assert(!NotesListFilter.matches(normal, scope: .pinned))
        assert(!NotesListFilter.matches(trashed, scope: .all))
        assert(NotesListFilter.matches(recovered, scope: .all, typeID: "type-meeting"))
        assert(!NotesListFilter.matches(normal, scope: .all, typeID: "type-meeting"))
        assert(!NotesListFilter.matches(recovered, scope: .all, bookID: "wrong-book"))
        assert(NotesListFilter.matches(normal, scope: .recent, recentStart: "2020-01-01"))
        assert(!NotesListFilter.matches(normal, scope: .recent, recentStart: "2099-01-01"))

        // Old quick-capture data still maps to the same normal note model.
        let legacy = try db.saveQuickCapture(existing: nil, day: "2025-01-01", text: "옛날 빠른 기록")!
        assert(NotesListFilter.matches(legacy, scope: .all))
        assert(legacy.visibleTitle.contains("빠른 기록"))
        let fresh = try db.createNote(typeID: "type-note")
        assert(fresh.visibleTitle == "새 메모")
        let written = try db.saveNote(fresh, title: "", bodyHTML: "<p>제목 없는 메모의 첫 줄</p>",
            typeID: "type-note", bookID: "", noteDate: today, status: "진행 중",
            sourceURL: "", pinned: false, archived: false, checkpoint: false)
        assert(written.visibleTitle.contains("제목 없는 메모의 첫 줄"))
        let backup = try db.exportBrowserCompatibleJSON()
        assert(!backup.isEmpty)
        // Importing a legacy backup must not reintroduce retired per-note archive state.
        let importRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MemoryHome-UX-Import-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: importRoot) }
        let importedDB = try LocalDatabase(directoryOverride: importRoot)
        var backupObject = try JSONSerialization.jsonObject(with: backup) as! [String: Any]
        var backupNotes = backupObject["notes"] as! [[String: Any]]
        for index in backupNotes.indices { backupNotes[index]["archived"] = true }
        backupObject["notes"] = backupNotes
        let oldBackup = try JSONSerialization.data(withJSONObject: backupObject)
        let importedCounts = try importedDB.importBrowserBackup(oldBackup)
        assert(importedCounts.notes == backupNotes.count)
        let importedNotes = try importedDB.notes()
        assert(importedNotes.allSatisfy { !$0.archived }, "Old JSON imports never hide notes")
        print("PASS UX consolidation: one note list, four filters, old capture support, inferred titles, retired archive migration/backup/idempotency/revisions")
    }
}
