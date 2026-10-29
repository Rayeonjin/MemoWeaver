import Foundation

@main
struct BackupSmoke {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MemoryHomeBackupSmoke-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let db = try LocalDatabase(directoryOverride: root)
        let note = try db.createNote(typeID: "type-note")
        _ = try db.saveNote(note, title: "원본 보존 시험", bodyHTML: "<p>중요한 내용</p>",
            typeID: note.typeID, bookID: "", noteDate: WorkOSDate.day(), status: "진행 중",
            sourceURL: "", pinned: false, archived: false, checkpoint: false)
        let first = try db.snapshotBackupIfNeeded()
        let second = try db.snapshotBackupIfNeeded()
        assert(first == second, "Same six-hour period does not create duplicate automatic backups")
        let forced = try db.snapshotBackupIfNeeded(force: true)
        assert(first != forced, "Manual backup creates a separate file")
        assert(FileManager.default.fileExists(atPath: first.path))
        assert(FileManager.default.fileExists(atPath: forced.path))
        let tempBackups = try FileManager.default.contentsOfDirectory(atPath:
            root.appendingPathComponent("Backups").path)
        assert(!tempBackups.contains(where: { $0.contains(".partial") }), "No partial snapshots remain")
        let opened = try LocalDatabase(directoryOverride: root)
        let currentlySaved = try opened.notes()
        assert(currentlySaved.contains(where: { $0.title == "원본 보존 시험" }))
        // Backup is independently readable by a fresh database connection.
        let restoreRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MemoryHomeRestoredBackup-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: restoreRoot) }
        try FileManager.default.createDirectory(at: restoreRoot, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: forced, to: restoreRoot.appendingPathComponent("WorkOS.sqlite"))
        let restored = try LocalDatabase(directoryOverride: restoreRoot)
        let recoveredNotes = try restored.notes()
        assert(recoveredNotes.contains(where: { $0.title == "원본 보존 시험" }))
        print("PASS backup: six-hour slot, manual backup, no leftover partials, restore readback")
    }
}
