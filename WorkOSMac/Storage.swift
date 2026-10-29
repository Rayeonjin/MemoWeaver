import Foundation
import SQLite3

private enum DBValue {
    case text(String), integer(Int), null
}

final class LocalDatabase {
    enum Failure: LocalizedError {
        case cannotOpen(String), sql(String), badBackup, unsupportedFile, backupTooLarge
        var errorDescription: String? {
            switch self {
            case .cannotOpen(let message): return "로컬 저장소를 열지 못했습니다: \(message)"
            case .sql(let message): return "SQLite 저장 오류: \(message)"
            case .badBackup: return "MemoWeaver JSON 백업이 손상되었거나 지원하지 않는 형식입니다. 이전 버전 백업도 지원하며 기존 기록은 유지했습니다."
            case .unsupportedFile: return "파일을 처리할 수 없습니다."
            case .backupTooLarge: return "JSON 백업은 최대 512MiB까지만 안전하게 처리합니다. 더 큰 데이터는 설정의 SQLite 스냅샷으로 백업하고 복구 안내를 확인하세요."
            }
        }
    }

    let directory: URL
    let databaseURL: URL
    private var handle: OpaquePointer?
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    private static let maxJSONBackupBytes = 512 * 1024 * 1024
    // New exports identify the independent product. Both identifiers keep
    // the exact same schema-1 payload; pre-rename backups stay importable.
    private static let backupAppID = "memoweaver-notes"
    private static func acceptsBackupApp(_ value: Any?) -> Bool {
        guard let app = value as? String else { return false }
        return app == backupAppID || app == "workos-notes"
    }
    private var transactionDepth = 0
    private var nextSavepointID = 0

    init(directoryOverride: URL? = nil) throws {
        directory = directoryOverride ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WorkOS", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        databaseURL = directory.appendingPathComponent("WorkOS.sqlite")
        let code = sqlite3_open_v2(databaseURL.path, &handle, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil)
        guard code == SQLITE_OK else { throw Failure.cannotOpen(String(cString: sqlite3_errmsg(handle))) }
        sqlite3_busy_timeout(handle, 5000)
        try execute("PRAGMA journal_mode=WAL")
        try execute("PRAGMA synchronous=FULL")
        try execute("PRAGMA foreign_keys=ON")
        try setup()
    }

    deinit { if let handle { sqlite3_close_v2(handle) } }

    private func setup() throws {
        let schema = [
            "CREATE TABLE IF NOT EXISTS notes (id TEXT PRIMARY KEY, title TEXT NOT NULL, body_plain TEXT NOT NULL, type_id TEXT NOT NULL, book_id TEXT NOT NULL, note_date TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT NOT NULL, raw_json TEXT NOT NULL)",
            "CREATE INDEX IF NOT EXISTS notes_updated ON notes(updated_at DESC)",
            "CREATE INDEX IF NOT EXISTS notes_type ON notes(type_id)",
            "CREATE TABLE IF NOT EXISTS note_notebooks (note_id TEXT NOT NULL REFERENCES notes(id) ON DELETE CASCADE, notebook_id TEXT NOT NULL, PRIMARY KEY(note_id,notebook_id))",
            "CREATE INDEX IF NOT EXISTS note_notebooks_book ON note_notebooks(notebook_id,note_id)",
            "CREATE TABLE IF NOT EXISTS categories (id TEXT PRIMARY KEY, category_kind TEXT NOT NULL, name TEXT NOT NULL, raw_json TEXT NOT NULL)",
            "CREATE TABLE IF NOT EXISTS archives (id TEXT PRIMARY KEY, name TEXT NOT NULL, text_content TEXT NOT NULL, line_count INTEGER NOT NULL, added_at TEXT NOT NULL)",
            "CREATE TABLE IF NOT EXISTS chunks (id INTEGER PRIMARY KEY AUTOINCREMENT, archive_id TEXT NOT NULL, title TEXT NOT NULL, content TEXT NOT NULL, from_line INTEGER NOT NULL, to_line INTEGER NOT NULL)",
            "CREATE INDEX IF NOT EXISTS chunks_archive ON chunks(archive_id)",
            "CREATE TABLE IF NOT EXISTS events (id TEXT PRIMARY KEY, at TEXT NOT NULL, raw_json TEXT NOT NULL)",
            "CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)",
            "CREATE TABLE IF NOT EXISTS memory_index (item_key TEXT PRIMARY KEY, entity_id TEXT NOT NULL, kind TEXT NOT NULL, title TEXT NOT NULL, signature TEXT NOT NULL, model TEXT NOT NULL, vector_json TEXT NOT NULL, from_line INTEGER NOT NULL DEFAULT 0, to_line INTEGER NOT NULL DEFAULT 0)",
            "CREATE INDEX IF NOT EXISTS memory_index_entity ON memory_index(entity_id)",
            "CREATE TABLE IF NOT EXISTS memory_links (link_key TEXT PRIMARY KEY, first_id TEXT NOT NULL, second_id TEXT NOT NULL, created_at TEXT NOT NULL, relation_kind TEXT NOT NULL DEFAULT 'related', memo TEXT NOT NULL DEFAULT '')",
            "CREATE TABLE IF NOT EXISTS memory_ai_facts (entity_id TEXT NOT NULL, ordinal INTEGER NOT NULL, signature TEXT NOT NULL, model TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(entity_id,ordinal))",
            "CREATE TABLE IF NOT EXISTS memory_ai_fact_runs (entity_id TEXT PRIMARY KEY, signature TEXT NOT NULL, model TEXT NOT NULL, finished_at TEXT NOT NULL)",
            "CREATE TABLE IF NOT EXISTS memory_ai_relations (pair_key TEXT PRIMARY KEY, from_id TEXT NOT NULL, to_id TEXT NOT NULL, from_signature TEXT NOT NULL, to_signature TEXT NOT NULL, model TEXT NOT NULL, payload TEXT NOT NULL)",
            "CREATE TABLE IF NOT EXISTS memory_relation_reviews (pair_key TEXT PRIMARY KEY, payload TEXT NOT NULL)",
            "CREATE INDEX IF NOT EXISTS memory_ai_relations_from ON memory_ai_relations(from_id)",
            "CREATE INDEX IF NOT EXISTS memory_ai_relations_to ON memory_ai_relations(to_id)",
            "CREATE TABLE IF NOT EXISTS virtual_memories (segment_id TEXT PRIMARY KEY, source_kind TEXT NOT NULL, source_id TEXT NOT NULL, source_signature TEXT NOT NULL, from_line INTEGER NOT NULL, to_line INTEGER NOT NULL, title TEXT NOT NULL, category TEXT NOT NULL, ai_reviewed INTEGER NOT NULL, created_at TEXT NOT NULL)",
            "CREATE INDEX IF NOT EXISTS virtual_memories_source ON virtual_memories(source_kind,source_id,from_line)",
            "CREATE TABLE IF NOT EXISTS schedule_items (id TEXT PRIMARY KEY, due_day TEXT NOT NULL, due_time TEXT NOT NULL, note_id TEXT NOT NULL, completed_at TEXT NOT NULL, updated_at TEXT NOT NULL, raw_json TEXT NOT NULL)",
            "CREATE INDEX IF NOT EXISTS schedule_items_day ON schedule_items(due_day,completed_at)",
            "CREATE INDEX IF NOT EXISTS schedule_items_note ON schedule_items(note_id)"
        ]
        for statement in schema { try execute(statement) }
        // Idempotent additive schema migration. Keep the existing WorkOS path,
        // note IDs and all prior memory_links rows untouched.
        let existingLinkColumns = Set(try query("PRAGMA table_info(memory_links)") {
            field($0, 1)
        })
        if !existingLinkColumns.contains("relation_kind") {
            try execute("ALTER TABLE memory_links ADD COLUMN relation_kind TEXT NOT NULL DEFAULT 'related'")
        }
        if !existingLinkColumns.contains("memo") {
            try execute("ALTER TABLE memory_links ADD COLUMN memo TEXT NOT NULL DEFAULT ''")
        }
        // One-time, idempotent, transactional migration. A separate metadata flag
        // avoids parsing every full note body on EVERY launch. Raw JSON remains
        // the canonical export; preexisting notes and IDs are NEVER rewritten.
        let migrated = try query("SELECT value FROM metadata WHERE key='note_notebooks_migrated_v1'") {
            field($0, 0)
        }.first == "1"
        if !migrated {
            let legacyNotes: [(String, [String])] = try query("SELECT id,raw_json FROM notes") { s in
                (field(s, 0), NotebookMembershipCore.from(WorkOSJSON.dictionary(field(s, 1))))
            }
            // A WAL-consistent recovery point must exist before this first
            // additive migration. Abort safely if the backup cannot be written.
            if !legacyNotes.isEmpty { _ = try snapshotBackupIfNeeded(force: true) }
            try transaction {
                for (id, notebooks) in legacyNotes {
                    for notebook in notebooks {
                        try execute("INSERT OR IGNORE INTO note_notebooks(note_id,notebook_id) VALUES (?,?)",
                                    [.text(id), .text(notebook)])
                    }
                }
                try execute("INSERT OR REPLACE INTO metadata(key,value) VALUES ('note_notebooks_migrated_v1','1')")
            }
        }
        let available: Int = try query("SELECT COUNT(*) FROM categories WHERE category_kind='type'") { Int(sqlite3_column_int($0, 0)) }.first ?? 0
        if available == 0 {
            for item in LocalDatabase.defaultTypes() { try insertCategory(item, kind: "type", replace: false) }
        }
    }

    private static func defaultTypes() -> [[String: Any]] {
        [
            ["id":"type-note", "name":"일반 메모", "icon":"notes", "template":"blank"],
            ["id":"type-work", "name":"업무 노트", "icon":"book", "template":"blank"],
            ["id":"type-meeting", "name":"회의록", "icon":"calendar", "template":"meeting"],
            ["id":"type-task", "name":"할 일", "icon":"checklist", "template":"checklist"],
            ["id":"type-msg", "name":"텔레그램 문구", "icon":"message", "template":"message"],
            ["id":"type-prompt", "name":"AI 프롬프트", "icon":"spark", "template":"prompt"],
            ["id":"type-url", "name":"웹 링크·자료", "icon":"link", "template":"link"]
        ]
    }

    private func prepared(_ sql: String, _ values: [DBValue]) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else { throw Failure.sql(String(cString: sqlite3_errmsg(handle))) }
        for (index, value) in values.enumerated() {
            let slot = Int32(index + 1)
            let result: Int32
            switch value {
            case .text(let text):
                result = text.withCString { sqlite3_bind_text(statement, slot, $0, -1, transient) }
            case .integer(let number): result = sqlite3_bind_int64(statement, slot, Int64(number))
            case .null: result = sqlite3_bind_null(statement, slot)
            }
            if result != SQLITE_OK {
                sqlite3_finalize(statement)
                throw Failure.sql(String(cString: sqlite3_errmsg(handle)))
            }
        }
        return statement
    }

    @discardableResult
    private func execute(_ sql: String, _ values: [DBValue] = []) throws -> Int {
        let statement = try prepared(sql, values)
        defer { sqlite3_finalize(statement) }
        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE || result == SQLITE_ROW else {
            throw Failure.sql(String(cString: sqlite3_errmsg(handle)))
        }
        return Int(sqlite3_changes(handle))
    }

    private func query<T>(_ sql: String, _ values: [DBValue] = [], map: (OpaquePointer) -> T) throws -> [T] {
        let statement = try prepared(sql, values)
        defer { sqlite3_finalize(statement) }
        var results: [T] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE { break }
            guard result == SQLITE_ROW else { throw Failure.sql(String(cString: sqlite3_errmsg(handle))) }
            results.append(map(statement))
        }
        return results
    }

    private func field(_ statement: OpaquePointer, _ index: Int32) -> String {
        guard let bytes = sqlite3_column_text(statement, index) else { return "" }
        let length = Int(sqlite3_column_bytes(statement, index))
        return String(decoding: UnsafeBufferPointer(start: bytes, count: length), as: UTF8.self)
    }

    // Nested operations (archives, virtual segments, AI facts) need savepoints.
    // A complete JSON import must either commit every item or none of them.
    private func transaction(_ work: () throws -> Void) throws {
        let outer = transactionDepth == 0
        nextSavepointID += 1
        let savepoint = "mw_tx_\(nextSavepointID)"
        if outer { try execute("BEGIN IMMEDIATE TRANSACTION") }
        else { try execute("SAVEPOINT " + savepoint) }
        transactionDepth += 1
        defer { transactionDepth -= 1 }
        do {
            try work()
            try execute(outer ? "COMMIT" : "RELEASE SAVEPOINT " + savepoint)
        } catch {
            if outer { _ = try? execute("ROLLBACK") }
            else {
                _ = try? execute("ROLLBACK TO SAVEPOINT " + savepoint)
                _ = try? execute("RELEASE SAVEPOINT " + savepoint)
            }
            throw error
        }
    }

    func notes() throws -> [WorkNote] {
        try query("SELECT raw_json FROM notes ORDER BY updated_at DESC") { statement in
            WorkNote.from(WorkOSJSON.dictionary(field(statement, 0)))
        }
    }

    func categories(kind: String) throws -> [WorkCategory] {
        try query("SELECT raw_json FROM categories WHERE category_kind=? ORDER BY name COLLATE NOCASE", [.text(kind)]) { statement in
            WorkCategory.from(WorkOSJSON.dictionary(field(statement, 0)))
        }
    }

    private func insertCategory(_ raw: [String: Any], kind: String, replace: Bool) throws {
        let category = WorkCategory.from(raw)
        let operation = replace ? "INSERT OR REPLACE" : "INSERT OR IGNORE"
        try execute("\(operation) INTO categories (id,category_kind,name,raw_json) VALUES (?,?,?,?)", [
            .text(category.id), .text(kind), .text(category.name), .text(category.rawJSON)
        ])
    }

    func createCategory(name: String, kind: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try insertCategory(["id": UUID().uuidString, "name": trimmed, "icon": "folder", "template": "blank"], kind: kind, replace: false)
    }

    private func insertNote(_ note: WorkNote, replace: Bool) throws {
        let operation = replace ? "INSERT OR REPLACE" : "INSERT OR IGNORE"
        try transaction {
            let affected = try execute("\(operation) INTO notes (id,title,body_plain,type_id,book_id,note_date,updated_at,deleted_at,raw_json) VALUES (?,?,?,?,?,?,?,?,?)", [
                .text(note.id), .text(note.title), .text(note.plainBody), .text(note.typeID), .text(note.bookID),
                .text(note.noteDate), .text(note.updatedAt), .text(note.deletedAt), .text(note.rawJSON)
            ])
            // INSERT OR IGNORE on existing IDs must not erase existing links.
            if affected > 0 {
                try execute("DELETE FROM note_notebooks WHERE note_id=?", [.text(note.id)])
                for id in note.notebookIDs {
                    try execute("INSERT INTO note_notebooks(note_id,notebook_id) VALUES (?,?)",
                                [.text(note.id), .text(id)])
                }
            }
        }
    }

    // v0.8.8: the note "archive" state is retired. This is an idempotent
    // migration of that single JSON attribute. A WAL-consistent snapshot must
    // succeed BEFORE any change; an SQLite transaction prevents partial edits.
    // Other columns and the original body/revisions/IDs/timestamps stay intact.
    @discardableResult
    func restoreLegacyArchivedNotesSafely() throws -> Int {
        struct Candidate { let id: String; var raw: [String: Any] }
        let candidates: [Candidate] = try query("SELECT id,raw_json FROM notes") { s in
            Candidate(id: field(s, 0), raw: WorkOSJSON.dictionary(field(s, 1)))
        }.filter { WorkOSJSON.bool($0.raw, "archived") }
        guard !candidates.isEmpty else { return 0 }
        _ = try snapshotBackupIfNeeded(force: true)
        try transaction {
            for var candidate in candidates {
                candidate.raw["archived"] = false
                try execute("UPDATE notes SET raw_json=? WHERE id=?", [
                    .text(try WorkOSJSON.encode(candidate.raw)), .text(candidate.id)
                ])
            }
        }
        return candidates.count
    }

    // One daily scratchpad per local calendar day. Created only when nonempty text is saved.
    // Backed by the ordinary notes table, so existing search, versions and JSON export work.
    func saveQuickCapture(existing: WorkNote?, day: String, text: String) throws -> WorkNote? {
        if existing == nil && text.isEmpty { return nil }
        if let existing, WorkOSQuickCapture.isPlainCapture(existing),
            WorkOSQuickCapture.plainText(existing) == text { return existing }
        if let existing, !WorkOSQuickCapture.isPlainCapture(existing) {
            throw Failure.sql("서식이 추가된 빠른 기록은 일반 메모 편집기에서 수정하세요. 원문을 덮어쓰지 않았습니다.")
        }
        let initial: WorkNote
        if let existing { initial = existing }
        else {
            var raw = WorkOSJSON.dictionary(WorkNote.make().rawJSON)
            raw["title"] = WorkOSQuickCapture.title(for: day)
            raw["noteDate"] = day
            raw["quickCaptureDay"] = day
            raw["quickCaptureText"] = ""
            initial = WorkNote.from(raw)
        }
        var result: WorkNote?
        try transaction {
            let saved = try saveNote(initial, title: initial.title,
                bodyHTML: WorkOSQuickCapture.html(text), typeID: initial.typeID,
                bookID: initial.bookID, noteDate: initial.noteDate, status: initial.status,
                sourceURL: initial.sourceURL, pinned: initial.pinned, archived: initial.archived,
                checkpoint: false)
            var raw = WorkOSJSON.dictionary(saved.rawJSON)
            raw["quickCaptureDay"] = day
            raw["quickCaptureText"] = text
            let changed = WorkNote.from(raw)
            try insertNote(changed, replace: true)
            result = changed
        }
        return result
    }

    // One independently editable quick note; old daily notes use the legacy method above.
    // No new table/schema needed: marker fields are stored in the ordinary raw JSON.
    func createQuickCaptureNote(day: String) throws -> WorkNote {
        var raw = WorkOSJSON.dictionary(WorkNote.make().rawJSON)
        raw["quickCaptureMode"] = "multi"
        raw["quickCaptureDay"] = day
        raw["noteDate"] = day
        let created = WorkNote.from(raw)
        try insertNote(created, replace: false)
        return created
    }

    func createNote(typeID: String, markdown: Bool = false,
                    bookID: String = "", pinned: Bool = false) throws -> WorkNote {
        var raw = WorkOSJSON.dictionary(WorkNote.make(typeID: typeID, markdown: markdown).rawJSON)
        raw["bookId"] = bookID
        raw["notebookIds"] = NotebookMembershipCore.normalized(primary: bookID, ids: [])
        raw["pinned"] = pinned
        let new = WorkNote.from(raw)
        try insertNote(new, replace: false)
        return new
    }

    func saveNote(_ old: WorkNote, title: String, bodyHTML: String, typeID: String,
                  bookID: String, noteDate: String, status: String, sourceURL: String,
                  pinned: Bool, archived: Bool, checkpoint: Bool,
                  convertLegacyBodyToMarkdown: Bool = false,
                  notebookIDs: [String]? = nil) throws -> WorkNote {
        var raw = WorkOSJSON.dictionary(old.rawJSON)
        // Calls that do not edit notebook membership retain all secondary IDs.
        // Old single-book callers changing the primary replace only the old
        // primary; explicit multi-select changes are passed as notebookIDs.
        let memberships: [String] = {
            if let notebookIDs { return NotebookMembershipCore.normalized(primary: bookID, ids: notebookIDs) }
            if bookID == old.bookID { return old.notebookIDs }
            return NotebookMembershipCore.normalized(primary: bookID,
                       ids: old.notebookIDs.filter { $0 != old.bookID })
        }()
        let primaryBookID = memberships.first ?? ""
        let migrating = convertLegacyBodyToMarkdown && !old.isMarkdown
        if migrating {
            // Must succeed before any legacy source is changed. SQLite backup
            // API includes WAL; a failure aborts the edit without touching it.
            _ = try snapshotBackupIfNeeded(force: true)
            if raw["legacyOriginalHTML"] == nil { raw["legacyOriginalHTML"] = old.bodyHTML }
            if raw["legacyOriginalWorkosBlocks"] == nil {
                raw["legacyOriginalWorkosBlocks"] = raw["workosBlocks"] ?? []
            }
            // The visible Markdown source now includes these extension blocks.
            // Keep the previous block JSON in the legacy archive, not twice.
            raw["workosBlocks"] = []
            raw["bodyFormat"] = "markdown"
            raw["legacyConvertedAt"] = WorkOSDate.now()
        }
        let changed = migrating || title != old.title || bodyHTML != old.bodyHTML || typeID != old.typeID ||
            memberships != old.notebookIDs || noteDate != old.noteDate || status != old.status ||
            sourceURL != old.sourceURL || pinned != old.pinned || archived != old.archived
        if !changed && !checkpoint { return old }
        let now = WorkOSDate.now()
        raw["title"] = title
        raw["body"] = bodyHTML
        raw["typeId"] = typeID
        raw["bookId"] = primaryBookID
        raw["notebookIds"] = memberships
        raw["noteDate"] = noteDate
        raw["status"] = status
        raw["sourceUrl"] = sourceURL
        raw["pinned"] = pinned
        raw["archived"] = archived
        if changed { raw["updatedAt"] = now }
        var revisions = WorkOSJSON.items(raw, "revisions")
        let last = revisions.last
        let differsFromLast = last == nil ||
            WorkOSJSON.string(last ?? [:], "body") != bodyHTML ||
            WorkOSJSON.string(last ?? [:], "title") != title ||
            WorkOSJSON.string(last ?? [:], "typeId") != typeID ||
            WorkOSJSON.string(last ?? [:], "bookId") != primaryBookID
        let elapsedSinceCheckpoint: TimeInterval = {
            guard let lastString = last?["at"] as? String else { return .infinity }
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return Date().timeIntervalSince(f.date(from: lastString) ?? .distantPast)
        }()
        if differsFromLast && (checkpoint || elapsedSinceCheckpoint >= 15 * 60) {
            revisions.append([
                "id": UUID().uuidString, "at": now, "title": title, "body": bodyHTML,
                "typeId": typeID, "bookId": primaryBookID, "notebookIds": memberships, "noteDate": noteDate,
                "status": status, "sourceUrl": sourceURL, "workosBlocks": WorkBlock.encode(old.workosBlocks),
                "action": last == nil ? "최초 작성" : (checkpoint ? "편집 세션 종료" : "자동 체크포인트")
            ])
            raw["revisions"] = revisions
        }
        let result = WorkNote.from(raw)
        try insertNote(result, replace: true)
        if checkpoint && differsFromLast { try addEvent(action: "편집", note: result) }
        return result
    }

    func saveBlocks(_ old: WorkNote, blocks: [WorkBlock], checkpoint: Bool) throws -> WorkNote {
        if old.workosBlocks == blocks && !checkpoint { return old }
        var raw = WorkOSJSON.dictionary(old.rawJSON)
        let now = WorkOSDate.now()
        let changed = old.workosBlocks != blocks
        raw["workosBlocks"] = WorkBlock.encode(blocks)
        if changed { raw["updatedAt"] = now }
        var revisions = WorkOSJSON.items(raw, "revisions")
        let last = revisions.last
        let lastBlocks = WorkBlock.read(WorkOSJSON.items(last ?? [:], "workosBlocks"))
        // Record changes as manual checkpoints or periodically; not every keystroke.
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let elapsed: TimeInterval = last.flatMap { formatter.date(from: WorkOSJSON.string($0, "at")) }
            .map { Date().timeIntervalSince($0) } ?? .infinity
        if (changed || checkpoint) && lastBlocks != blocks && (checkpoint || elapsed > 15 * 60) {
            var revision: [String: Any] = [
                "id": UUID().uuidString, "at": now, "title": old.title, "body": old.bodyHTML,
                "typeId": old.typeID, "bookId": old.bookID, "workosBlocks": WorkBlock.encode(blocks),
                "action": checkpoint ? "확장 블록 체크포인트" : "확장 블록 자동 체크포인트"
            ]
            if !old.noteDate.isEmpty { revision["noteDate"] = old.noteDate }
            revisions.append(revision)
            raw["revisions"] = revisions
        }
        let updated = WorkNote.from(raw)
        try insertNote(updated, replace: true)
        return updated
    }

    func updateDeleted(_ note: WorkNote, delete: Bool) throws -> WorkNote {
        var raw = WorkOSJSON.dictionary(note.rawJSON)
        raw["deletedAt"] = delete ? WorkOSDate.now() : ""
        raw["updatedAt"] = WorkOSDate.now()
        let changed = WorkNote.from(raw)
        try insertNote(changed, replace: true)
        try addEvent(action: delete ? "휴지통 이동" : "복원", note: changed)
        return changed
    }

    func addProgress(to note: WorkNote, body: String) throws -> WorkNote {
        var raw = WorkOSJSON.dictionary(note.rawJSON)
        var entries = WorkOSJSON.items(raw, "progress")
        let now = WorkOSDate.now()
        entries.append(["id": UUID().uuidString, "at": now, "noteDate": WorkOSDate.day(), "body": "<p>\(escapeHTML(body))</p>"])
        raw["progress"] = entries
        raw["updatedAt"] = now
        let result = WorkNote.from(raw)
        try insertNote(result, replace: true)
        try addEvent(action: "진행 추가", note: result)
        return result
    }

    private func addEvent(action: String, note: WorkNote) throws {
        let now = WorkOSDate.now()
        let id = UUID().uuidString
        let raw: [String: Any] = ["id": id, "at": now, "noteId": note.id, "noteTitle": note.title, "action": action]
        try execute("INSERT OR REPLACE INTO events (id,at,raw_json) VALUES (?,?,?)", [
            .text(id), .text(now), .text(try WorkOSJSON.encode(raw))
        ])
    }

    func archives() throws -> [WorkArchive] {
        try query("SELECT id,name,line_count,added_at FROM archives ORDER BY added_at DESC") { s in
            WorkArchive(id: field(s, 0), name: field(s, 1),
                        lineCount: Int(sqlite3_column_int64(s, 2)), addedAt: field(s, 3))
        }
    }

    func archiveText(id: String) throws -> String {
        try query("SELECT text_content FROM archives WHERE id=?", [.text(id)]) { field($0, 0) }.first ?? ""
    }

    func archiveChunks() throws -> [WorkChunk] {
        try query("SELECT id,archive_id,title,content,from_line,to_line FROM chunks") { statement in
            WorkChunk(
                id: sqlite3_column_int64(statement, 0), sourceID: field(statement, 1),
                title: field(statement, 2), text: field(statement, 3),
                fromLine: Int(sqlite3_column_int(statement, 4)), toLine: Int(sqlite3_column_int(statement, 5))
            )
        }
    }

    @discardableResult
    func addArchive(id: String = UUID().uuidString, name: String, content: String,
                    addedAt: String = WorkOSDate.now()) throws -> Bool {
        let existing: Int = try query("SELECT COUNT(*) FROM archives WHERE id=? OR (name=? AND text_content=?)", [
            .text(id), .text(name), .text(content)
        ]) { Int(sqlite3_column_int($0, 0)) }.first ?? 0
        if existing > 0 { return false }
        // Keep physical-line numbering consistent with virtual pointers and
        // the read-only excerpt view for CRLF text from older VS Code files.
        let lines = VirtualMemoryCore.lines(content)
        try transaction {
            try execute("INSERT INTO archives (id,name,text_content,line_count,added_at) VALUES (?,?,?,?,?)", [
                .text(id), .text(name), .text(content), .integer(lines.count), .text(addedAt)
            ])
            var start = 0
            while start < lines.count {
                var end = start
                var charCount = 0
                while end < lines.count && end - start < 48 {
                    let next = lines[end].count + 1
                    if end > start && charCount + next > 2300 { break }
                    charCount += next
                    end += 1
                }
                let excerpt = lines[start..<end].joined(separator: "\n")
                try execute("INSERT INTO chunks (archive_id,title,content,from_line,to_line) VALUES (?,?,?,?,?)", [
                    .text(id), .text(name), .text(String(excerpt.prefix(3500))),
                    .integer(start + 1), .integer(end)
                ])
                if end >= lines.count { break }
                start = max(start + 1, end - 5)
            }
        }
        return true
    }

    func deleteArchive(id: String) throws {
        try transaction {
            try execute("DELETE FROM memory_index WHERE entity_id=?", [.text("archive:" + id)])
            try execute("DELETE FROM memory_links WHERE first_id=? OR second_id=?", [.text("archive:" + id), .text("archive:" + id)])
            try discardInferredMemory(entityID: "archive:" + id)
            let fragmentIDs = try query("SELECT segment_id FROM virtual_memories WHERE source_kind='archive' AND source_id=?", [.text(id)]) { field($0, 0) }
            for segmentID in fragmentIDs {
                try execute("DELETE FROM memory_index WHERE entity_id=?", [.text("virtual:" + segmentID)])
                try discardInferredMemory(entityID: "virtual:" + segmentID)
            }
            try execute("DELETE FROM virtual_memories WHERE source_kind='archive' AND source_id=?", [.text(id)])
            try execute("DELETE FROM chunks WHERE archive_id=?", [.text(id)])
            try execute("DELETE FROM archives WHERE id=?", [.text(id)])
        }
    }

    func importBrowserBackup(_ data: Data) throws -> (notes: Int, archives: Int) {
        guard data.count < Self.maxJSONBackupBytes else { throw Failure.backupTooLarge }
        guard let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Self.acceptsBackupApp(raw["app"]),
              (raw["schema"] as? Int) == 1,
              let notes = raw["notes"] as? [[String: Any]],
              let types = raw["types"] as? [[String: Any]],
              let books = raw["books"] as? [[String: Any]],
              notes.count < 60000,
              notes.allSatisfy({ ($0["id"] as? String)?.isEmpty == false && $0["body"] is String }),
              types.allSatisfy({ ($0["id"] as? String)?.isEmpty == false }),
              books.allSatisfy({ ($0["id"] as? String)?.isEmpty == false }) else { throw Failure.badBackup }
        let sources = WorkOSJSON.items(raw, "sources")
        guard sources.allSatisfy({ ($0["id"] as? String)?.isEmpty == false &&
                                   $0["name"] is String && $0["text"] is String }) else {
            throw Failure.badBackup
        }
        let events = WorkOSJSON.items(raw, "events")
        // Validate all assets before writing any note or attachment. The files
        // are immutable and new assets are removed if database import fails.
        let importedAssets = try MemoWeaverAttachments.validatedBackupEntries(raw["attachments"])
        let addedAssets = try MemoWeaverAttachments.installBackupEntries(importedAssets, in: directory)
        var assetImportCommitted = false
        defer {
            if !assetImportCommitted {
                for url in addedAssets { try? FileManager.default.removeItem(at: url) }
            }
        }
        // One atomic import, including every archive and user-confirmed link.
        // Nested transactions become SAVEPOINTs and participate in outer rollback.
        var newNotes = 0
        var newArchives = 0
        try transaction {
        for type in types { try insertCategory(type, kind: "type", replace: false) }
        for book in books { try insertCategory(book, kind: "book", replace: false) }
        try transaction {
            for dict in notes {
                guard dict["id"] is String, dict["body"] is String else { continue }
                var normalized = dict
                normalized["archived"] = false
                let note = WorkNote.from(normalized)
                let existed: Int = try query("SELECT COUNT(*) FROM notes WHERE id=?", [.text(note.id)]) {
                    Int(sqlite3_column_int($0, 0))
                }.first ?? 0
                if existed == 0 {
                    try insertNote(note, replace: false)
                    newNotes += 1
                }
            }
            for item in events {
                guard let id = item["id"] as? String else { continue }
                try execute("INSERT OR IGNORE INTO events (id,at,raw_json) VALUES (?,?,?)", [
                    .text(id), .text(WorkOSJSON.string(item, "at")), .text(try WorkOSJSON.encode(item))
                ])
            }
        }
        for item in sources {
            guard let name = item["name"] as? String, let text = item["text"] as? String else { continue }
            if try addArchive(id: WorkOSJSON.string(item, "id", default: UUID().uuidString),
                              name: name, content: text,
                              addedAt: WorkOSJSON.string(item, "addedAt", default: WorkOSDate.now())) {
                newArchives += 1
            }
        }
        // Backward-compatible: older backups have no scheduleItems key.
        if let scheduleItems = raw["scheduleItems"] as? [[String: Any]] {
            try importScheduleItems(scheduleItems)
        }
        // Confirmed personal memory links are durable user data, not a computed AI cache.
        if let links = raw["memoryLinks"] as? [[String: Any]] {
            for entry in links {
                let a = WorkOSJSON.string(entry, "first")
                let b = WorkOSJSON.string(entry, "second")
                if a.isEmpty || b.isEmpty || a == b { continue }
                try addMemoryLink(MemoryLink(a, b,
                    createdAt: WorkOSJSON.string(entry, "createdAt", default: WorkOSDate.now()),
                    relationKind: MemoryLink.sanitizeKind(WorkOSJSON.string(entry, "relationKind", default: "related")),
                    memo: String(WorkOSJSON.string(entry, "memo").prefix(1000))))
            }
        }
        // Optional v0.9.9 field. Restore only mappings whose original source
        // exists unchanged; stale/malformed pointers are silently ignored.
        let rawVirtual = WorkOSJSON.items(raw, "virtualSegments")
        if rawVirtual.count <= 20000 {
            let grouped = Dictionary(grouping: rawVirtual) {
                WorkOSJSON.string($0, "sourceKind") + "|" + WorkOSJSON.string($0, "sourceID")
            }
            for (_, rows) in grouped {
                guard let first = rows.first else { continue }
                let kind = WorkOSJSON.string(first, "sourceKind")
                let id = WorkOSJSON.string(first, "sourceID")
                let text: String
                if kind == "archive" {
                    guard let archived = try query("SELECT text_content FROM archives WHERE id=?", [.text(id)],
                        map: { field($0, 0) }).first else { continue }
                    text = archived
                } else if kind == "note", let note = try self.notes().first(where: { $0.id == id }) {
                    text = LegacyNoteTextConverter.editableText(for: note)
                } else { continue }
                let segments = rows.compactMap { item -> VirtualMemory? in
                    guard let from = item["fromLine"] as? Int, let to = item["toLine"] as? Int else { return nil }
                    return VirtualMemory(id: WorkOSJSON.string(item, "id"), sourceKind: kind,
                        sourceID: id, sourceSignature: WorkOSJSON.string(item, "signature"),
                        fromLine: from, toLine: to, title: WorkOSJSON.string(item, "title"),
                        category: WorkOSJSON.string(item, "category", default: "uncertain"),
                        aiReviewed: WorkOSJSON.bool(item, "aiReviewed"),
                        createdAt: WorkOSJSON.string(item, "createdAt", default: WorkOSDate.now()))
                }.sorted { $0.fromLine < $1.fromLine }
                if VirtualMemoryCore.valid(segments, source: text, kind: kind, id: id) {
                    try saveVirtualMemories(segments, source: text, kind: kind, id: id)
                }
            }
        }
        // AI results are optional derived data. Import only when BOTH current
        // sources and their exact quoted evidence match; never trust backup JSON.
        if let rawFacts = raw["aiMemoryFacts"] as? [[String: Any]], rawFacts.count <= 30000 {
            var grouped: [String: [MemoryFact]] = [:]
            for item in rawFacts {
                guard let data = try? JSONSerialization.data(withJSONObject: item),
                      let fact = try? JSONDecoder().decode(MemoryFact.self, from: data),
                      let source = try evidenceDocument(entityID: fact.entityID),
                      source.signature == fact.sourceSignature,
                      MemoryRelationCore.factLabels[fact.kind] != nil,
                      source.excerpt.contains(fact.quote), fact.quote.count >= 4 else { continue }
                grouped[fact.entityID, default: []].append(fact)
            }
            for (id, facts) in grouped {
                let selected = Array(facts.sorted { $0.ordinal < $1.ordinal }.prefix(6))
                guard let first = selected.first,
                      selected.allSatisfy({ $0.model == first.model && $0.sourceSignature == first.sourceSignature }) else { continue }
                try saveAIFacts(selected, entityID: id, signature: first.sourceSignature, model: first.model)
            }
        }
        if let rawRelations = raw["aiMemoryRelations"] as? [[String: Any]], rawRelations.count <= 30000 {
            for item in rawRelations {
                guard let data = try? JSONSerialization.data(withJSONObject: item),
                      let relation = try? JSONDecoder().decode(MemoryInferredRelation.self, from: data),
                      let source = try evidenceDocument(entityID: relation.fromID),
                      let target = try evidenceDocument(entityID: relation.toID),
                      source.signature == relation.fromSignature, target.signature == relation.toSignature,
                      (MemoryRelationCore.relationLabels[relation.relationType] != nil || relation.relationType == "none"),
                      (!relation.hasRelationship ||
                          (source.excerpt.contains(relation.fromQuote) && target.excerpt.contains(relation.toQuote))) else { continue }
                try saveAIRelation(relation)
            }
        }
        // Restored feedback only applies to relationships that were themselves
        // accepted by current-source quote and signature validation above.
        if let rawReviews = raw["memoryRelationReviews"] as? [[String: Any]], rawReviews.count <= 30000 {
            let known = Dictionary(uniqueKeysWithValues: try aiMemoryRelations().map { ($0.id, $0) })
            for item in rawReviews {
                guard let data = try? JSONSerialization.data(withJSONObject: item),
                      let review = try? JSONDecoder().decode(MemoryRelationReview.self, from: data),
                      let relation = known[review.pairKey], relation.hasRelationship,
                      review.applies(to: relation),
                      review.decision == "irrelevant" || review.decision == "helpful" else { continue }
                try saveMemoryRelationReview(review)
            }
        }
        } // Atomic JSON import ends here.
        assetImportCommitted = true
        return (newNotes, newArchives)
    }

    // Explicit disaster recovery is distinct from the add-only importer.
    // Snapshot the live database first, clear in one transaction, then run the
    // same validated importer. A failure rolls back the complete replacement.
    func replaceAllWithBrowserBackup(_ data: Data) throws -> (notes: Int, archives: Int) {
        guard data.count < Self.maxJSONBackupBytes else { throw Failure.backupTooLarge }
        guard let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Self.acceptsBackupApp(raw["app"]),
              raw["schema"] as? Int == 1,
              let items = raw["notes"] as? [[String: Any]],
              let _ = raw["types"] as? [[String: Any]],
              let _ = raw["books"] as? [[String: Any]],
              items.count < 60000,
              items.allSatisfy({ ($0["id"] as? String)?.isEmpty == false && $0["body"] is String })
            else { throw Failure.badBackup }
        _ = try snapshotBackupIfNeeded(force: true)
        var imported = (notes: 0, archives: 0)
        try transaction {
            for table in ["memory_relation_reviews", "memory_ai_relations", "memory_ai_fact_runs",
                          "memory_ai_facts", "memory_index", "memory_links", "virtual_memories",
                          "chunks", "archives", "events", "schedule_items", "notes", "categories"] {
                try execute("DELETE FROM " + table)
            }
            imported = try importBrowserBackup(data)
            // An older backup may contain an empty type collection.
            let count: Int = try query("SELECT COUNT(*) FROM categories WHERE category_kind='type'") {
                Int(sqlite3_column_int($0, 0))
            }.first ?? 0
            if count == 0 {
                for row in Self.defaultTypes() { try insertCategory(row, kind: "type", replace: false) }
            }
        }
        return imported
    }

    func exportBrowserCompatibleJSON() throws -> Data {
        let notes = try query("SELECT raw_json FROM notes") { WorkOSJSON.dictionary(field($0, 0)) }
        let types = try query("SELECT raw_json FROM categories WHERE category_kind='type'") { WorkOSJSON.dictionary(field($0, 0)) }
        let books = try query("SELECT raw_json FROM categories WHERE category_kind='book'") { WorkOSJSON.dictionary(field($0, 0)) }
        let events = try query("SELECT raw_json FROM events ORDER BY at DESC") { WorkOSJSON.dictionary(field($0, 0)) }
        let sources: [[String: Any]] = try query("SELECT id,name,text_content,line_count,added_at FROM archives") { s in
            ["id": field(s, 0), "name": field(s, 1), "text": field(s, 2),
             "lineCount": Int(sqlite3_column_int64(s, 3)), "addedAt": field(s, 4)]
        }
        let memoryLinks: [[String: Any]] = try confirmedLinks().map {
            ["first": $0.first, "second": $0.second, "createdAt": $0.createdAt,
             "relationKind": $0.relationKind, "memo": $0.memo]
        }
        let scheduleItems: [[String: Any]] = try scheduledItems().compactMap { item in
            let data = try? JSONEncoder().encode(item)
            return data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        }
        let virtualSegments: [[String: Any]] = try virtualMemories().map { s in
            ["id": s.id, "sourceKind": s.sourceKind, "sourceID": s.sourceID,
             "signature": s.sourceSignature, "fromLine": s.fromLine, "toLine": s.toLine,
             "title": s.title, "category": s.category, "aiReviewed": s.aiReviewed,
             "createdAt": s.createdAt]
        }
        let aiFacts: [[String: Any]] = try aiMemoryFacts().compactMap { fact in
            (try? JSONEncoder().encode(fact)).flatMap {
                try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
            }
        }
        let aiRelations: [[String: Any]] = try aiMemoryRelations().compactMap { relation in
            (try? JSONEncoder().encode(relation)).flatMap {
                try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
            }
        }
        let reviews: [[String: Any]] = try memoryRelationReviews().compactMap { review in
            (try? JSONEncoder().encode(review)).flatMap {
                try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
            }
        }
        // Base64 is included only in user-requested JSON exports. Auto SQLite
        // snapshots use adjacent attachment companions instead of growing DB.
        let attachments = try MemoWeaverAttachments.backupEntries(in: directory)
        var snapshot: [String: Any] = [
            "memoryRelationReviews": reviews,
            "virtualSegments": virtualSegments,
            "aiMemoryFacts": aiFacts,
            "aiMemoryRelations": aiRelations,
            "scheduleItems": scheduleItems,
            "memoryLinks": memoryLinks,
            "app": Self.backupAppID, "schema": 1,
            "createdAt": WorkOSDate.now(), "updatedAt": WorkOSDate.now(),
            "types": types, "books": books, "notes": notes, "events": events, "sources": sources
        ]
        if !attachments.isEmpty { snapshot["attachments"] = attachments }
        let data = try JSONSerialization.data(withJSONObject: snapshot, options: [.prettyPrinted, .sortedKeys])
        guard data.count < Self.maxJSONBackupBytes else { throw Failure.backupTooLarge }
        return data
    }

    // MARK: - Local schedule / D-Day / reminder plan (user-authored and durable)

    func scheduledItems() throws -> [WorkScheduleItem] {
        let decoded: [WorkScheduleItem?] = try query(
            "SELECT raw_json FROM schedule_items ORDER BY due_day ASC,due_time ASC,updated_at DESC") { s in
            guard let data = field(s, 0).data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(WorkScheduleItem.self, from: data)
        }
        return decoded.compactMap { $0 }
    }

    func saveScheduleItem(_ original: WorkScheduleItem, preserveUpdateTime: Bool = false) throws {
        var item = original
        item.normalize()
        guard !item.id.isEmpty,
              !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              ScheduleDates.parseDay(item.dueDay) != nil else {
            throw Failure.sql("일정 제목 또는 마감 날짜가 올바르지 않습니다.")
        }
        if !preserveUpdateTime { item.updatedAt = WorkOSDate.now() }
        let raw = String(decoding: try JSONEncoder().encode(item), as: UTF8.self)
        try execute("INSERT OR REPLACE INTO schedule_items (id,due_day,due_time,note_id,completed_at,updated_at,raw_json) VALUES (?,?,?,?,?,?,?)", [
            .text(item.id), .text(item.dueDay), .text(item.dueTime), .text(item.noteID),
            .text(item.completedAt), .text(item.updatedAt), .text(raw)
        ])
    }

    func deleteScheduleItem(_ id: String) throws {
        try execute("DELETE FROM schedule_items WHERE id=?", [.text(id)])
    }

    private func importScheduleItems(_ items: [[String: Any]]) throws {
        for raw in items {
            guard let data = try? JSONSerialization.data(withJSONObject: raw),
                  let item = try? JSONDecoder().decode(WorkScheduleItem.self, from: data),
                  !item.id.isEmpty else { continue }
            let present: Int = try query("SELECT COUNT(*) FROM schedule_items WHERE id=?", [.text(item.id)]) {
                Int(sqlite3_column_int($0, 0))
            }.first ?? 0
            if present == 0 { try saveScheduleItem(item, preserveUpdateTime: true) }
        }
    }

    // MARK: - Virtual memory pointers (non-destructive, revision-bound)

    func virtualMemories() throws -> [VirtualMemory] {
        try query("SELECT segment_id,source_kind,source_id,source_signature,from_line,to_line,title,category,ai_reviewed,created_at FROM virtual_memories ORDER BY source_kind,source_id,from_line") { s in
            VirtualMemory(id: field(s, 0), sourceKind: field(s, 1), sourceID: field(s, 2),
                sourceSignature: field(s, 3), fromLine: Int(sqlite3_column_int64(s, 4)),
                toLine: Int(sqlite3_column_int64(s, 5)), title: field(s, 6),
                category: field(s, 7), aiReviewed: sqlite3_column_int(s, 8) != 0,
                createdAt: field(s, 9))
        }
    }

    func saveVirtualMemories(_ segments: [VirtualMemory], source: String, kind: String, id: String) throws {
        guard (kind == "note" || kind == "archive"),
              VirtualMemoryCore.valid(segments, source: source, kind: kind, id: id) else {
            throw Failure.sql("가상 메모 줄 범위 또는 원문 서명이 잘못되어 저장하지 않았습니다.")
        }
        // No existing virtual index is removed until the replacement has been
        // validated in full. Changes to pointers and derived vectors are atomic.
        try transaction {
            let oldKeys = try query("SELECT segment_id FROM virtual_memories WHERE source_kind=? AND source_id=?", [.text(kind), .text(id)]) { field($0, 0) }
            // Label changes alter embedding text even when line boundaries
            // (and hence segment IDs) remain unchanged. Drop the old derived
            // vectors so nothing stale appears in search or the memory graph.
            for key in oldKeys {
                try execute("DELETE FROM memory_index WHERE entity_id=?", [.text("virtual:" + key)])
                try discardInferredMemory(entityID: "virtual:" + key)
            }
            try execute("DELETE FROM virtual_memories WHERE source_kind=? AND source_id=?", [.text(kind), .text(id)])
            for s in segments {
                try execute("INSERT INTO virtual_memories (segment_id,source_kind,source_id,source_signature,from_line,to_line,title,category,ai_reviewed,created_at) VALUES (?,?,?,?,?,?,?,?,?,?)", [
                    .text(s.id), .text(s.sourceKind), .text(s.sourceID), .text(s.sourceSignature),
                    .integer(s.fromLine), .integer(s.toLine), .text(s.title), .text(s.category),
                    .integer(s.aiReviewed ? 1 : 0), .text(s.createdAt)
                ])
            }
        }
    }

    func removeVirtualMemories(kind: String, id: String) throws {
        try transaction {
            let old = try query("SELECT segment_id FROM virtual_memories WHERE source_kind=? AND source_id=?", [.text(kind), .text(id)]) { field($0, 0) }
            for key in old {
                try execute("DELETE FROM memory_index WHERE entity_id=?", [.text("virtual:" + key)])
                try discardInferredMemory(entityID: "virtual:" + key)
            }
            try execute("DELETE FROM virtual_memories WHERE source_kind=? AND source_id=?", [.text(kind), .text(id)])
        }
    }

    // MARK: - Semantic memory index (derived and rebuildable)

    func memorySignatures(model: String = "bge-m3") throws -> [String: String] {
        let pairs: [(String, String)] = try query(
            "SELECT item_key,signature FROM memory_index WHERE model=?", [.text(model)]) { s in
            (field(s, 0), field(s, 1))
        }
        return Dictionary(uniqueKeysWithValues: pairs)
    }

    func memoryVectors(model: String = "bge-m3") throws -> [MemoryVector] {
        let parsed: [MemoryVector?] = try query(
            "SELECT item_key,entity_id,kind,title,signature,vector_json,from_line,to_line FROM memory_index WHERE model=?", [.text(model)]) { s in
            let values = (field(s, 5).data(using: .utf8)).flatMap {
                try? JSONDecoder().decode([Double].self, from: $0)
            }
            guard let values, !values.isEmpty else { return nil }
            return MemoryVector(id: field(s, 0), entityID: field(s, 1),
                kind: field(s, 2), title: field(s, 3), signature: field(s, 4),
                values: values, fromLine: Int(sqlite3_column_int(s, 6)),
                toLine: Int(sqlite3_column_int(s, 7)))
        }
        return parsed.compactMap { $0 }
    }

    func saveMemoryVector(item: MemoryIndexItem, model: String, vector: [Double]) throws {
        guard !vector.isEmpty && vector.count < 10000 && vector.allSatisfy(\.isFinite) else {
            throw Failure.sql("Ollama embedding has invalid dimensions or contains NaN.")
        }
        let encoded = String(decoding: try JSONEncoder().encode(vector), as: UTF8.self)
        try execute("INSERT OR REPLACE INTO memory_index (item_key,entity_id,kind,title,signature,model,vector_json,from_line,to_line) VALUES (?,?,?,?,?,?,?,?,?)", [
            .text(item.id), .text(item.entityID), .text(item.kind), .text(item.title),
            .text(item.signature), .text(model), .text(encoded),
            .integer(item.fromLine), .integer(item.toLine)
        ])
    }

    func removeMemoryIndexItem(_ key: String) throws {
        try execute("DELETE FROM memory_index WHERE item_key=?", [.text(key)])
    }

    func removeObsoleteVectors(validKeys: Set<String>, model: String = "bge-m3") throws {
        let stored = try query("SELECT item_key FROM memory_index WHERE model=?", [.text(model)]) { field($0, 0) }
        for key in stored where !validKeys.contains(key) {
            try execute("DELETE FROM memory_index WHERE item_key=?", [.text(key)])
        }
    }

    // MARK: - User-confirmed, bidirectional links

    func confirmedLinks() throws -> [MemoryLink] {
        try query("SELECT first_id,second_id,created_at,relation_kind,memo FROM memory_links ORDER BY created_at DESC") { s in
            MemoryLink(field(s, 0), field(s, 1), createdAt: field(s, 2),
                relationKind: field(s, 3), memo: field(s, 4))
        }
    }

    // Legacy links and imported backups never overwrite existing user choices.
    func addMemoryLink(_ link: MemoryLink) throws {
        guard !link.first.isEmpty && !link.second.isEmpty && link.first != link.second else { return }
        try execute("INSERT OR IGNORE INTO memory_links (link_key,first_id,second_id,created_at,relation_kind,memo) VALUES (?,?,?,?,?,?)", [
            .text(link.id), .text(link.first), .text(link.second), .text(link.createdAt),
            .text(MemoryLink.sanitizeKind(link.relationKind)), .text(String(link.memo.prefix(1000)))
        ])
    }

    // Only a direct UI edit updates an existing manual connection. AI never
    // changes or deletes a human-confirmed relation, type or explanation.
    func upsertMemoryLink(_ link: MemoryLink) throws {
        guard !link.first.isEmpty && !link.second.isEmpty && link.first != link.second else { return }
        try execute("INSERT INTO memory_links (link_key,first_id,second_id,created_at,relation_kind,memo) VALUES (?,?,?,?,?,?) ON CONFLICT(link_key) DO UPDATE SET relation_kind=excluded.relation_kind,memo=excluded.memo", [
            .text(link.id), .text(link.first), .text(link.second), .text(link.createdAt),
            .text(MemoryLink.sanitizeKind(link.relationKind)), .text(String(link.memo.prefix(1000)))
        ])
    }

    func removeMemoryLink(_ link: MemoryLink) throws {
        try execute("DELETE FROM memory_links WHERE link_key=?", [.text(link.id)])
    }

    // MARK: - v0.9.11 evidence-gated AI memory (separate, additive SQLite tables)

    func evidenceDocument(entityID: String) throws -> MemoryEvidenceDocument? {
        if entityID.hasPrefix("note:") {
            let id = String(entityID.dropFirst(5))
            guard let raw = try query("SELECT raw_json FROM notes WHERE id=? AND deleted_at=''",
                                      [.text(id)], map: { field($0, 0) }).first else { return nil }
            let note = WorkNote.from(WorkOSJSON.dictionary(raw))
            let text = LegacyNoteTextConverter.editableText(for: note)
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return MemoryEvidenceDocument(id: entityID, title: note.visibleTitle, text: text)
        }
        if entityID.hasPrefix("archive:") {
            let id = String(entityID.dropFirst(8))
            guard let values = try query("SELECT name,text_content FROM archives WHERE id=?", [.text(id)],
                map: { (field($0, 0), field($0, 1)) }).first else { return nil }
            return MemoryEvidenceDocument(id: entityID, title: values.0, text: values.1)
        }
        if entityID.hasPrefix("virtual:") {
            let id = String(entityID.dropFirst(8))
            let segment = try query("SELECT source_kind,source_id,source_signature,from_line,to_line,title FROM virtual_memories WHERE segment_id=?",
                [.text(id)]) { statement -> (String, String, String, Int, Int, String) in
                (field(statement, 0), field(statement, 1), field(statement, 2),
                 Int(sqlite3_column_int(statement, 3)), Int(sqlite3_column_int(statement, 4)), field(statement, 5))
            }.first
            guard let part = segment,
                  let parent = try evidenceDocument(entityID: part.0 + ":" + part.1),
                  VirtualMemoryCore.signature(parent.text) == part.2 else { return nil }
            let excerpt = VirtualMemoryCore.sourceText(parent.text, from: part.3, to: part.4)
            guard !excerpt.isEmpty else { return nil }
            return MemoryEvidenceDocument(id: entityID, title: part.5, text: excerpt,
                                          fromLine: part.3, toLine: part.4)
        }
        return nil
    }

    func aiMemoryFacts() throws -> [MemoryFact] {
        try query("SELECT payload FROM memory_ai_facts ORDER BY entity_id,ordinal") { statement in
            field(statement, 0).data(using: .utf8).flatMap { try? JSONDecoder().decode(MemoryFact.self, from: $0) }
        }.compactMap { $0 }
    }

    func aiMemoryRelations() throws -> [MemoryInferredRelation] {
        try query("SELECT payload FROM memory_ai_relations ORDER BY pair_key") { statement in
            field(statement, 0).data(using: .utf8).flatMap { try? JSONDecoder().decode(MemoryInferredRelation.self, from: $0) }
        }.compactMap { $0 }
    }

    func memoryRelationReviews() throws -> [MemoryRelationReview] {
        try query("SELECT payload FROM memory_relation_reviews ORDER BY pair_key") { statement in
            field(statement, 0).data(using: .utf8).flatMap {
                try? JSONDecoder().decode(MemoryRelationReview.self, from: $0)
            }
        }.compactMap { $0 }
    }

    func saveMemoryRelationReview(_ review: MemoryRelationReview) throws {
        guard review.decision == "irrelevant" || review.decision == "helpful",
              !review.fromSignature.isEmpty, !review.toSignature.isEmpty else {
            throw Failure.sql("기억 관계 평가의 값이 올바르지 않습니다.")
        }
        let raw = String(decoding: try JSONEncoder().encode(review), as: UTF8.self)
        try execute("INSERT OR REPLACE INTO memory_relation_reviews (pair_key,payload) VALUES (?,?)", [
            .text(review.pairKey), .text(raw)
        ])
    }

    func deleteMemoryRelationReview(_ key: String) throws {
        try execute("DELETE FROM memory_relation_reviews WHERE pair_key=?", [.text(key)])
    }

    func aiFactsAreCurrent(entityID: String, signature: String, model: String) throws -> Bool {
        let count: Int = try query("SELECT COUNT(*) FROM memory_ai_fact_runs WHERE entity_id=? AND signature=? AND model=?", [
            .text(entityID), .text(signature), .text(model)
        ]) { Int(sqlite3_column_int($0, 0)) }.first ?? 0
        return count > 0
    }

    func saveAIFacts(_ facts: [MemoryFact], entityID: String, signature: String, model: String) throws {
        guard facts.count <= 6 && facts.allSatisfy({ $0.entityID == entityID &&
            $0.sourceSignature == signature && $0.model == model }) else {
            throw Failure.sql("AI 사실 추출의 출처 서명이 일치하지 않습니다.")
        }
        try transaction {
            try execute("DELETE FROM memory_ai_facts WHERE entity_id=?", [.text(entityID)])
            try execute("INSERT OR REPLACE INTO memory_ai_fact_runs (entity_id,signature,model,finished_at) VALUES (?,?,?,?)", [
                .text(entityID), .text(signature), .text(model), .text(WorkOSDate.now())
            ])
            for fact in facts {
                let payload = String(decoding: try JSONEncoder().encode(fact), as: UTF8.self)
                try execute("INSERT INTO memory_ai_facts (entity_id,ordinal,signature,model,payload) VALUES (?,?,?,?,?)", [
                    .text(fact.entityID), .integer(fact.ordinal), .text(fact.sourceSignature),
                    .text(fact.model), .text(payload)
                ])
            }
        }
    }

    func saveAIRelation(_ relation: MemoryInferredRelation) throws {
        guard !relation.fromID.isEmpty, !relation.toID.isEmpty, relation.fromID != relation.toID,
              relation.fromSignature != "", relation.toSignature != "" else {
            throw Failure.sql("AI 관계의 원본 ID나 서명이 잘못되었습니다.")
        }
        let payload = String(decoding: try JSONEncoder().encode(relation), as: UTF8.self)
        try execute("INSERT OR REPLACE INTO memory_ai_relations (pair_key,from_id,to_id,from_signature,to_signature,model,payload) VALUES (?,?,?,?,?,?,?)", [
            .text(relation.id), .text(relation.fromID), .text(relation.toID),
            .text(relation.fromSignature), .text(relation.toSignature),
            .text(relation.model), .text(payload)
        ])
    }

    private func discardInferredMemory(entityID: String) throws {
        try execute("DELETE FROM memory_ai_fact_runs WHERE entity_id=?", [.text(entityID)])
        try execute("DELETE FROM memory_ai_facts WHERE entity_id=?", [.text(entityID)])
        try execute("DELETE FROM memory_ai_relations WHERE from_id=? OR to_id=?", [.text(entityID), .text(entityID)])
    }

    // Crash-consistent SQLite snapshot using the backup API (works with WAL).
    // Keep the historic SQLite directory and pre-v0.9.60 snapshots intact.
    // New snapshots are named MemoWeaver; only NEW-named snapshots are
    // subject to automatic retention, so an upgrade never prunes old backups.
    // Automatic backups use six-hour slots; a user-requested backup is unique.
    @discardableResult
    func snapshotBackupIfNeeded(force: Bool = false) throws -> URL {
        let fm = FileManager.default
        let folder = directory.appendingPathComponent("Backups", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let hour = Calendar.current.component(.hour, from: Date())
        let slot = (hour / 6) * 6
        let day = WorkOSDate.day()
        let name = String(format: "MemoWeaver-%@-%02d", day, slot)
        let fileName: String
        if force {
            let time = DateFormatter()
            time.dateFormat = "HHmmss"
            fileName = name + "-manual-" + time.string(from: Date()) + "-" + UUID().uuidString.prefix(6) + ".sqlite"
        } else {
            fileName = name + ".sqlite"
        }
        let destination = folder.appendingPathComponent(fileName)
        if fm.fileExists(atPath: destination.path) {
            // A new image may have been pasted after the first snapshot in
            // this six-hour slot. Add hard-linked files to the companion.
            try MemoWeaverAttachments.snapshotCompanion(for: destination, storageDirectory: directory)
            return destination
        }

        // Do not expose incomplete snapshots under a normal backup filename.
        let temporary = folder.appendingPathComponent(".snapshot-" + UUID().uuidString + ".partial")
        var target: OpaquePointer?
        guard sqlite3_open(temporary.path, &target) == SQLITE_OK, let target else {
            if let target { sqlite3_close(target) }
            try? fm.removeItem(at: temporary)
            throw Failure.sql("백업 대상 파일을 열 수 없습니다.")
        }
        var snapshotCompleted = false
        var targetOpen = true
        defer {
            if targetOpen { sqlite3_close(target) }
            if !snapshotCompleted { try? fm.removeItem(at: temporary) }
        }
        guard let operation = sqlite3_backup_init(target, "main", handle, "main") else {
            throw Failure.sql("SQLite 스냅샷을 시작할 수 없습니다.")
        }
        let result = sqlite3_backup_step(operation, -1)
        let finish = sqlite3_backup_finish(operation)
        guard result == SQLITE_DONE && finish == SQLITE_OK else {
            throw Failure.sql("SQLite 스냅샷이 완료되지 않았습니다.")
        }
        guard sqlite3_close(target) == SQLITE_OK else {
            throw Failure.sql("SQLite 백업 파일을 정상적으로 닫지 못했습니다.")
        }
        targetOpen = false
        try fm.moveItem(at: temporary, to: destination)
        snapshotCompleted = true
        try MemoWeaverAttachments.snapshotCompanion(for: destination, storageDirectory: directory)
        // Bound local growth: keep the newest two recovery points even if large,
        // then up to 28 snapshots and approximately 512 MiB total by file size.
        // This limits the impact of large imported archives and vector indexes.
        // Old WorkOS- snapshots are intentionally excluded from retention:
        // they are pre-migration recovery points and must remain untouched.
        let completed = try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey])
            .filter { $0.lastPathComponent.hasPrefix("MemoWeaver-") && $0.pathExtension == "sqlite" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        let budget: Int64 = 512 * 1024 * 1024
        var retainedBytes: Int64 = 0
        for (position, candidate) in completed.enumerated() {
            let length = Int64((try? candidate.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            if position >= 2 && (position >= 28 || retainedBytes + length > budget) {
                try? fm.removeItem(at: candidate)
                try? fm.removeItem(at: MemoWeaverAttachments.backupCompanionDirectory(for: candidate))
            } else {
                retainedBytes += length
            }
        }
        return destination
    }

}

func escapeHTML(_ text: String) -> String {
    text.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}
