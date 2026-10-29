import Foundation
import SQLite3

@main
struct QualityV0917Smoke {
    static func assertTrue(_ value: @autoclosure () -> Bool, _ problem: String) {
        if !value() { fatalError("FAIL: " + problem) }
    }
    static func main() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("MW-0917-QA-" + UUID().uuidString)
        let producerDir = base.appendingPathComponent("producer")
        let consumerDir = base.appendingPathComponent("consumer")
        defer { try? FileManager.default.removeItem(at: base) }
        try FileManager.default.createDirectory(at: producerDir, withIntermediateDirectories: true)
        let producer = try LocalDatabase(directoryOverride: producerDir)
        let original = try producer.createNote(typeID: "type-work", markdown: true,
                                               bookID: "qa-book", pinned: true)
        assertTrue(original.bookID == "qa-book" && original.pinned, "filtered creation keeps notebook and pin")
        let saved = try producer.saveNote(original, title: "특수보고서", bodyHTML: "업무 오늘 앱 을 진행한 기록",
            typeID: original.typeID, bookID: original.bookID, noteDate: "2026-10-26",
            status: "진행 중", sourceURL: "", pinned: true, archived: false, checkpoint: false)
        let all = try producer.notes()
        for word in ["업무", "오늘", "앱"] {
            let result = WorkOSSearch.find(question: word, notes: all, chunks: [])
            assertTrue(result.contains(where: { $0.sourceID == saved.id }), "Korean short word search: " + word)
        }
        let signature = VirtualMemoryCore.signature(saved.bodyHTML)
        let segment = VirtualMemory(id: "qa-seg-1", sourceKind: "note", sourceID: saved.id,
            sourceSignature: signature, fromLine: 1, toLine: 1, title: "본문 구간",
            category: "record", aiReviewed: false, createdAt: WorkOSDate.now())
        let afterSegmentation = WorkOSSearch.find(question: "특수보고서", notes: all,
            chunks: [], virtualMemories: [segment],
            virtualSourceTexts: ["note:" + saved.id: saved.bodyHTML])
        assertTrue(afterSegmentation.contains(where: { $0.id == "note-parent:" + saved.id }),
                   "parent title search survives virtual segmentation")
        let archiveContent = "수동 기록입니다\n두 번째 행"
        _ = try producer.addArchive(name: "중요거래자료.txt", content: archiveContent)
        _ = try producer.addArchive(name: "FAIL.txt", content: "주입 실패 검증")
        let archived = try producer.archives().first(where: { $0.name == "중요거래자료.txt" })!
        let segmentArchive = VirtualMemory(id: "qa-archive-1", sourceKind: "archive", sourceID: archived.id,
            sourceSignature: VirtualMemoryCore.signature(archiveContent),
            fromLine: 1, toLine: 1, title: "자료 첫 줄", category: "record",
            aiReviewed: false, createdAt: WorkOSDate.now())
        let archivedResults = WorkOSSearch.find(question: "중요거래자료", notes: [], chunks: try producer.archiveChunks(),
            virtualMemories: [segmentArchive], virtualSourceTexts: ["archive:" + archived.id: archiveContent])
        assertTrue(archivedResults.contains(where: { $0.id == "archive-parent:" + archived.id }),
                   "physical filename survives virtual archive segmentation")
        let backup = try producer.exportBrowserCompatibleJSON()
        let consumer = try LocalDatabase(directoryOverride: consumerDir)
        let existing = try consumer.createNote(typeID: "type-note", markdown: true)
        let triggerSQL = "CREATE TRIGGER qa_fail BEFORE INSERT ON archives WHEN NEW.name='FAIL.txt' BEGIN SELECT RAISE(ABORT, 'injected failure'); END;"
        var sqlite: OpaquePointer?
        assertTrue(sqlite3_open(consumer.databaseURL.path, &sqlite) == SQLITE_OK, "trigger db open")
        assertTrue(sqlite3_exec(sqlite, triggerSQL, nil, nil, nil) == SQLITE_OK, "failure trigger setup")
        sqlite3_close(sqlite)
        do {
            _ = try consumer.importBrowserBackup(backup)
            fatalError("FAIL: import must abort on archive trigger")
        } catch { }
        let afterFailedImport = try consumer.notes()
        let afterFailedArchives = try consumer.archives()
        assertTrue(afterFailedImport.count == 1 && afterFailedImport[0].id == existing.id,
                   "atomic import rollback left original note untouched")
        assertTrue(afterFailedArchives.isEmpty, "atomic import left no partial archive")
        assertTrue(sqlite3_open(consumer.databaseURL.path, &sqlite) == SQLITE_OK, "trigger cleanup open")
        assertTrue(sqlite3_exec(sqlite, "DROP TRIGGER qa_fail", nil, nil, nil) == SQLITE_OK, "drop injection trigger")
        sqlite3_close(sqlite)
        let added = try consumer.importBrowserBackup(backup)
        assertTrue(added.notes == 1 && added.archives == 2, "successful additive backup import")
        let afterSuccessfulImport = try consumer.notes()
        assertTrue(afterSuccessfulImport.count == 2, "import preserved existing note")
        let repeated = try consumer.importBrowserBackup(backup)
        assertTrue(repeated.notes == 0 && repeated.archives == 0, "idempotent import")
        // Inject a failure in the *destructive* restore too: all original
        // records must survive, including the extra note and both archives.
        assertTrue(sqlite3_open(consumer.databaseURL.path, &sqlite) == SQLITE_OK,
                   "restore injection db open")
        assertTrue(sqlite3_exec(sqlite, triggerSQL, nil, nil, nil) == SQLITE_OK,
                   "restore failure trigger setup")
        sqlite3_close(sqlite)
        do {
            _ = try consumer.replaceAllWithBrowserBackup(backup)
            fatalError("FAIL: destructive restore must roll back on an archive trigger")
        } catch { }
        let afterFailedRestore = try consumer.notes()
        let archivesAfterFailedRestore = try consumer.archives()
        assertTrue(afterFailedRestore.count == 2 && archivesAfterFailedRestore.count == 2,
                   "failed whole restore retained all original notes and archives")
        assertTrue(sqlite3_open(consumer.databaseURL.path, &sqlite) == SQLITE_OK,
                   "restore injection cleanup open")
        assertTrue(sqlite3_exec(sqlite, "DROP TRIGGER qa_fail", nil, nil, nil) == SQLITE_OK,
                   "drop restore injection trigger")
        sqlite3_close(sqlite)
        let restored = try consumer.replaceAllWithBrowserBackup(backup)
        assertTrue(restored.notes == 1 && restored.archives == 2, "whole snapshot restore")
        let snapshots = try FileManager.default.contentsOfDirectory(at:
            consumerDir.appendingPathComponent("Backups", isDirectory: true),
            includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "sqlite" }
        assertTrue(!snapshots.isEmpty, "restore produced SQLite recovery snapshot")
        var snapshot: OpaquePointer?
        assertTrue(sqlite3_open_v2(snapshots[0].path, &snapshot, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
                   "SQLite pre-restore snapshot opens")
        var countStatement: OpaquePointer?
        assertTrue(sqlite3_prepare_v2(snapshot, "SELECT COUNT(*) FROM notes", -1,
                                      &countStatement, nil) == SQLITE_OK,
                   "snapshot notes count prepared")
        assertTrue(sqlite3_step(countStatement) == SQLITE_ROW &&
                   sqlite3_column_int(countStatement, 0) == 2,
                   "SQLite snapshot retained two notes before destructive restore")
        sqlite3_finalize(countStatement)
        sqlite3_close(snapshot)
        let afterFullRestore = try consumer.notes()
        assertTrue(afterFullRestore.count == 1 && afterFullRestore[0].id == saved.id,
                   "whole restore removes out-of-backup note")
        let exportedAgain = try consumer.exportBrowserCompatibleJSON()
        let dict = try JSONSerialization.jsonObject(with: exportedAgain) as! [String: Any]
        assertTrue((dict["notes"] as? [[String: Any]])?.count == 1,
                   "round-trip export after full restore")
        print("PASS QA v0.9.17 Korean search, title indexes, filtered creation, atomic import/restore rollback, SQLite snapshot, idempotent import, JSON round-trip")
    }
}
