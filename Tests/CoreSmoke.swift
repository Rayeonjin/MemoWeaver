import Foundation

@main
struct CoreSmoke {
    static func main() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkOSCoreSmoke-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let database = try LocalDatabase(directoryOverride: temporaryDirectory)
        let fresh = try database.createNote(typeID: "type-note")
        let saved = try database.saveNote(fresh, title: "API 응답 지연", bodyHTML: "<p>타임아웃 값 조정 후 해결</p>",
            typeID: fresh.typeID, bookID: "", noteDate: WorkOSDate.day(), status: "완료", sourceURL: "",
            pinned: false, archived: false, checkpoint: false)
        assert(saved.revisions.count == 1, "First meaningful save makes revision")
        let amended = try database.saveNote(saved, title: "API 응답 지연", bodyHTML: "<p>타임아웃 값 조정 후 해결</p><p>재발방지 모니터링 추가</p>",
            typeID: saved.typeID, bookID: "", noteDate: saved.noteDate, status: "완료", sourceURL: "",
            pinned: false, archived: false, checkpoint: true)
        assert(amended.revisions.count == 2, "Manual checkpoint adds revision")
        let recovered = try database.notes().first(where: { $0.id == fresh.id })!
        assert(recovered.bodyHTML.contains("모니터링"))
        try database.createCategory(name: "프로젝트 A", kind: "book")
        let books = try database.categories(kind: "book")
        assert(books.contains(where: { $0.name == "프로젝트 A" }))
        var lines = (1...11_005).map { index in "\(index)번째 일반 기록: 정기 점검" }
        lines[10_390] = "2026 장애: API 응답 지연은 타임아웃 재설정으로 해결"
        let contents = lines.joined(separator: "\n")
        let decoded = try ArchiveDecoder.read(Data(contents.utf8))
        assert(decoded.text == contents)
        let added = try database.addArchive(name: "확장자없는10k줄", content: decoded.text)
        assert(added)
        let chunks = try database.archiveChunks()
        let related = WorkOSSearch.find(question: "API 응답 지연 해결", notes: try database.notes(), chunks: chunks)
        assert(related.contains(where: { $0.kind == "archive" && $0.text.contains("타임아웃") }), "Search retrieves old text")
        let output = try database.exportBrowserCompatibleJSON()
        let exported = try JSONSerialization.jsonObject(with: output) as! [String: Any]
        assert((exported["app"] as? String) == "workos-notes")
        assert((exported["sources"] as? [[String: Any]])?.count == 1)
        let imported = try database.importBrowserBackup(output)
        assert(imported.notes == 0 && imported.archives == 0, "Repeat import is additive without duplicates")
        let missingExtension = try ArchiveDecoder.read(contents.data(using: .utf8)!)
        assert(missingExtension.text.count > 100_000)
        for binary in [Data([0x25, 0x50, 0x44, 0x46, 0x2d]), Data([0x89, 0x50, 0x4e, 0x47])] {
            do { _ = try ArchiveDecoder.read(binary); assertionFailure("Binary file wrongly accepted") }
            catch ArchiveDecoder.DecodeFailure.binary { }
        }
        let legacyID = UUID().uuidString
        let legacyNote: [String: Any] = [
            "id": legacyID, "title": "2025년 운영회의 기록", "body": "<h2>회의 결과</h2><p>작업 승인</p>",
            "typeId": "type-meeting", "bookId": "book-legacy", "noteDate": "2025-11-03",
            "status": "완료", "createdAt": "2025-11-03T10:00:00.000Z", "updatedAt": "2025-11-03T11:00:00.000Z",
            "revisions": [["id":"r-1", "at":"2025-11-03T10:00:00.000Z", "title":"회의", "body":"<p>임시</p>", "action":"최초 작성"]],
            "progress": [["id":"p-1", "at":"2025-11-03T11:00:00.000Z", "noteDate":"2025-11-03", "body":"<p>결정 확인</p>"]],
            "links": ["another-note"], "customLegacyField": "preserve-me"
        ]
        let legacyBackup: [String: Any] = [
            "app":"workos-notes", "schema":1,
            "types":[["id":"type-meeting", "name":"회의록", "icon":"calendar", "template":"meeting"]],
            "books":[["id":"book-legacy", "name":"이전 프로젝트", "icon":"folder"]],
            "notes":[legacyNote], "events":[],
            "sources":[["id":"archive-legacy", "name":"확장자없는_기존파일", "text":"오래된 기록\n작업 승인", "lineCount":2, "addedAt":"2025-11-03T09:00:00.000Z"]]
        ]
        let legacyData = try JSONSerialization.data(withJSONObject: legacyBackup)
        let migrated = try database.importBrowserBackup(legacyData)
        assert(migrated.notes == 1 && migrated.archives == 1)
        let foundLegacy = try database.notes().first(where: { $0.id == legacyID })!
        assert(foundLegacy.revisions.count == 1 && foundLegacy.progress.count == 1)
        assert(WorkOSJSON.string(WorkOSJSON.dictionary(foundLegacy.rawJSON), "customLegacyField") == "preserve-me")
        let secondImport = try database.importBrowserBackup(legacyData)
        assert(secondImport.notes == 0 && secondImport.archives == 0)
        let reopenedDatabase = try LocalDatabase(directoryOverride: temporaryDirectory)
        let reloadedNotes = try reopenedDatabase.notes()
        assert(reloadedNotes.contains(where: { $0.id == legacyID }))
        let cp949URL = URL(fileURLWithPath: CommandLine.arguments[1])
        let cp949 = try ArchiveDecoder.read(Data(contentsOf: cp949URL))
        assert(cp949.text.contains("회의 기록"), "CP949 Korean decoded")
        try database.snapshotBackupIfNeeded()
        print("PASS: SQLite saves, revisions, custom categories, 11005-line archive, retrieval, JSON backup, idempotent migration, binary filter")
        print("Local test database:", database.databaseURL.path)
    }
}
