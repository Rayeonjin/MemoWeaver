import Foundation

@main
struct BrandBackupCompatibilityV0960 {
    static func check(_ condition: Bool, _ label: String) {
        guard condition else { fatalError("FAIL " + label) }
        print("PASS " + label)
    }
    static func withAppID(_ data: Data, _ app: String) throws -> Data {
        var source = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        source["app"] = app
        return try JSONSerialization.data(withJSONObject: source, options: .sortedKeys)
    }
    static func main() throws {
        let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let main = try LocalDatabase(directoryOverride: folder.appendingPathComponent("original"))
        let note = try main.createNote(typeID: "type-note", markdown: true)
        _ = try main.saveNote(note, title: "오래된 메모", bodyHTML: "줄 하나\n줄 둘", typeID: note.typeID,
                              bookID: "", noteDate: note.noteDate, status: note.status,
                              sourceURL: "", pinned: false, archived: false, checkpoint: false)
        _ = try main.addArchive(id: "arch-before-rename", name: "legacy.txt", content: "첫 줄\n둘째 줄")
        let newBackup = try main.exportBrowserCompatibleJSON()
        let json = try JSONSerialization.jsonObject(with: newBackup) as! [String: Any]
        check(json["app"] as? String == "memoweaver-notes", "new JSON backup uses MemoWeaver identity")
        check(json["schema"] as? Int == 1, "JSON schema 1 unchanged")
        check((json["notes"] as? [[String: Any]])?.contains(where: { $0["id"] as? String == note.id }) == true,
              "original note ID and source retained")
        check((json["sources"] as? [[String: Any]])?.contains(where: { $0["id"] as? String == "arch-before-rename" }) == true,
              "old imported text retained")
        check(json["virtualSegments"] != nil && json["memoryLinks"] != nil,
              "virtual memory and relation backup fields preserved")
        check(main.databaseURL.lastPathComponent == "WorkOS.sqlite", "historic database filename kept for compatibility")
        let legacyBackup = try withAppID(newBackup, "workos-notes")
        for (label, source) in [("new", newBackup), ("legacy", legacyBackup)] {
            let restored = try LocalDatabase(directoryOverride: folder.appendingPathComponent(label))
            _ = try restored.importBrowserBackup(source)
            check(try restored.notes().contains(where: { $0.id == note.id }), "\(label) backup restores note ID")
            check(try restored.archives().contains(where: { $0.id == "arch-before-rename" }),
                  "\(label) backup restores source")
            let replaced = try restored.replaceAllWithBrowserBackup(source)
            check(replaced.notes >= 1, "\(label) backup full-restore accepted")
            check(try restored.notes().contains(where: { $0.id == note.id }),
                  "\(label) full-restore preserves existing note ID")
        }
        let rejected = try withAppID(newBackup, "not-an-app")
        let before = try main.notes().count
        do {
            _ = try main.importBrowserBackup(rejected)
            fatalError("Unexpected acceptance of unknown backup identifier")
        } catch LocalDatabase.Failure.badBackup {
            print("PASS unknown backup app rejected")
        }
        check(try main.notes().count == before, "invalid import leaves existing records untouched")
        let snapshot = try main.snapshotBackupIfNeeded(force: true)
        check(snapshot.lastPathComponent.hasPrefix("MemoWeaver-"), "new SQLite snapshots have MemoWeaver name")
        let historic = snapshot.deletingLastPathComponent().appendingPathComponent("WorkOS-2024-01-01-00.sqlite")
        try Data("legacy untouched".utf8).write(to: historic)
        _ = try main.snapshotBackupIfNeeded(force: true)
        check(try Data(contentsOf: historic) == Data("legacy untouched".utf8),
              "existing old-name SQLite snapshot not rewritten")
        print("PASS all branding and JSON/SQLite backward compatibility tests")
    }
}
