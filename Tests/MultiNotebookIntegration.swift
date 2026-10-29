import Foundation
import SQLite3

@main
struct Smoke {
    static func check(_ value: @autoclosure () -> Bool, _ label: String) {
        guard value() else { fputs("FAIL \(label)\n", stderr); exit(1) }
        print("PASS \(label)")
    }
    static func membershipCount(_ path: String, noteID: String) -> Int {
        var handle: OpaquePointer?
        guard sqlite3_open_v2(path, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let db = handle else { fatalError("SQLite test db could not open") }
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM note_notebooks WHERE note_id=?", -1, &statement, nil) == SQLITE_OK,
              let statement else { fatalError("membership table is missing") }
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        _ = noteID.withCString { sqlite3_bind_text(statement, 1, $0, -1, transient) }
        guard sqlite3_step(statement) == SQLITE_ROW else { fatalError("membership count query failed") }
        return Int(sqlite3_column_int(statement, 0))
    }
    static func main() throws {
        let fixture = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let db = try LocalDatabase(directoryOverride: fixture)
        let legacy = try db.notes().first { $0.id == "old-note-id" }!
        check(legacy.bookID == "book-A", "legacy bookId preserved")
        check(legacy.notebookIDs == ["book-A"], "legacy membership migrated")
        check(membershipCount(db.databaseURL.path, noteID: legacy.id) == 1, "legacy membership link indexed in SQLite")
        check(FileManager.default.fileExists(atPath: fixture.appendingPathComponent("Backups").path), "pre-migration SQLite snapshot made")
        check(NotesListFilter.matches(legacy, scope: .all, bookID: "book-A"), "legacy note filter")
        let fresh = try db.createNote(typeID: "type-note", markdown: true, bookID: "book-A")
        let edited = try db.saveNote(fresh, title: "multi", bodyHTML: "A", typeID: fresh.typeID,
            bookID: "book-A", noteDate: fresh.noteDate, status: fresh.status, sourceURL: "",
            pinned: false, archived: false, checkpoint: false, notebookIDs: ["book-A", "book-B", "book-A"])
        check(edited.notebookIDs == ["book-A", "book-B"], "secondary notebooks persisted without duplicating ID")
        check(membershipCount(db.databaseURL.path, noteID: fresh.id) == 2, "membership table holds two links to one memo")
        check(NotesListFilter.matches(edited, scope: .all, bookID: "book-A") &&
              NotesListFilter.matches(edited, scope: .all, bookID: "book-B"), "both notebook filters return the same note")
        let metadataEdit = try db.saveNote(edited, title: "multi 2", bodyHTML: "A", typeID: edited.typeID,
            bookID: "book-A", noteDate: edited.noteDate, status: edited.status, sourceURL: "",
            pinned: true, archived: false, checkpoint: false)
        check(metadataEdit.notebookIDs == ["book-A", "book-B"], "ordinary metadata save preserves secondary notebooks")
        let removed = try db.saveNote(metadataEdit, title: metadataEdit.title, bodyHTML: metadataEdit.bodyHTML,
            typeID: metadataEdit.typeID, bookID: "book-B", noteDate: metadataEdit.noteDate,
            status: metadataEdit.status, sourceURL: "", pinned: true, archived: false,
            checkpoint: false, notebookIDs: ["book-B"])
        check(removed.notebookIDs == ["book-B"], "uncheck removes membership without deleting note")
        check(membershipCount(db.databaseURL.path, noteID: fresh.id) == 1, "removed link deleted from index")
        let deleted = try db.updateDeleted(removed, delete: true)
        let restored = try db.updateDeleted(deleted, delete: false)
        check(restored.notebookIDs == ["book-B"], "trash and restore keep notebook membership")
        let restoredDB = try LocalDatabase(directoryOverride: fixture)
        let restartedNotes = try restoredDB.notes()
        check(restartedNotes.first { $0.id == fresh.id }?.notebookIDs == ["book-B"], "restart keeps memberships")
        let backup = try db.exportBrowserCompatibleJSON()
        let other = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        let importedDB = try LocalDatabase(directoryOverride: other)
        _ = try importedDB.importBrowserBackup(backup)
        let importedNotes = try importedDB.notes()
        check(importedNotes.first { $0.id == fresh.id }?.notebookIDs == ["book-B"], "export/import restores multiple notebooks")
        check(importedNotes.first { $0.id == legacy.id }?.notebookIDs == ["book-A"], "export/import retains older single notebook")
        print("PASS all database membership cases")
    }
}
