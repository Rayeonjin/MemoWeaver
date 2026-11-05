import Foundation
import SQLite3

@main struct UsabilityReleaseSmoke {
    static func check(_ okay: @autoclosure () throws -> Bool, _ description: String) rethrows {
        let passed = try okay()
        precondition(passed, description)
    }
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mw-release-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let db = try LocalDatabase(directoryOverride: directory)
        try db.createWelcomeNoteIfNeeded()
        let welcome = try db.notes().first!
        check(welcome.isMarkdown && welcome.bodyHTML.contains("⌘N"), "welcome content")
        _ = try db.updateDeleted(welcome, delete: true)
        try db.createWelcomeNoteIfNeeded()
        try check(try db.notes().count == 1, "welcome never respawns after deletion")
        let emptyBackup: [String: Any] = ["app":"memoweaver-notes", "schema":1, "notes":[], "types":[], "books":[], "sources":[]]
        _ = try db.replaceAllWithVerifiedBrowserBackup(JSONSerialization.data(withJSONObject: emptyBackup))
        try db.createWelcomeNoteIfNeeded()
        try check(try db.notes().isEmpty, "intentional empty restore remains empty")
        func save(_ note: WorkNote, _ title: String, _ body: String, status: String = "진행 중", date: String = "2026-11-05", notebooks: [String] = []) throws -> WorkNote {
            try db.saveNote(note, title: title, bodyHTML: body, typeID: note.typeID, bookID: notebooks.first ?? "", noteDate: date, status: status, sourceURL: "", pinned: false, archived: false, checkpoint: true, notebookIDs: notebooks)
        }
        let target = try save(db.createNote(typeID: "type-note", markdown: true), "대상 메모", "본문")
        let source = try save(db.createNote(typeID: "type-note", markdown: true), "참조 메모", "문장 [[대상 메모]]\n`[[가짜]]`\n```text\n[[가짜]]\n```\n" + MemoWeaverWikiLinks.source(.init(id: target.id, title: target.title)))
        let linkHTML = MarkdownPreviewCore.render(MemoWeaverWikiLinks.source(.init(id: target.id, title: "연결 <안전>"))).html
        check(linkHTML.contains("memoweaver-note://open") && linkHTML.contains("&lt;안전&gt;"), "preview link URL and escaped title")
        check(!MarkdownPreviewCore.render("`[[example]]`").html.contains("memoweaver-note:"), "inline code is not linked")
        check(!MarkdownPreviewCore.render("$[[example]]$").html.contains("memoweaver-note:"), "math is not linked")
        let refs = MemoWeaverWikiLinks.references(in: source.bodyHTML)
        check(refs.count == 2 && refs[0].line == 1 && refs[1].line == 6, "wiki links skip inline and fenced code; source lines preserved")
        check(MemoWeaverWikiLinks.bindings(source)["대상 메모"] == target.id, "typed title binds to ID")
        let renamed = try save(target, "바뀐 제목", "본문")
        check(MemoWeaverWikiLinks.resolve("대상 메모", bindings: MemoWeaverWikiLinks.bindings(source), candidates: [.init(id: renamed.id, title: renamed.title)]) == renamed.id, "rename retains typed-title link")
        check(MemoWeaverWikiLinks.previewSource(source).contains("[[\(target.id)|대상 메모]]"), "read-only preview retains bound ID")
        let before = source.revisions.count
        let metadata = try save(source, source.title, source.bodyHTML, status: "완료", date: "2026-12-31", notebooks: ["book-one", "book-two"])
        check(metadata.revisions.count == before + 1, "metadata checkpoint captured")
        let stable = try save(metadata, metadata.title, metadata.bodyHTML, status: metadata.status, date: metadata.noteDate, notebooks: metadata.notebookIDs)
        check(stable.revisions.count == metadata.revisions.count, "unchanged checkpoint not duplicated")
        let png = Data(base64Encoded:"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aKx8AAAAASUVORK5CYII=")!
        try MemoWeaverAttachments.validateReferences(in: [["body": "`![example](attachments/00000000-0000-0000-0000-000000000001.png)`"]], storageDirectory: directory)
        let path = try MemoWeaverAttachments.storePNG(png, in: directory)
        _ = try save(db.createNote(typeID: "type-note", markdown: true), "이미지", "![image](\(path))")
        let backup = try db.exportBrowserCompatibleJSON()
        let restored = try LocalDatabase(directoryOverride: directory.appendingPathComponent("restore"))
        _ = try restored.replaceAllWithVerifiedBrowserBackup(backup)
        check(MemoWeaverAttachments.read(path, in: restored.directory) == png, "portable image backup")
        let copy = try restored.notes().first { $0.id == source.id }!
        check(MemoWeaverWikiLinks.bindings(copy)["대상 메모"] == target.id, "wiki binding survives JSON restore")
        var missing = try JSONSerialization.jsonObject(with: backup) as! [String: Any]
        missing["attachments"] = []
        let cleanDB = try LocalDatabase(directoryOverride: directory.appendingPathComponent("clean"))
        do {
            _ = try cleanDB.replaceAllWithVerifiedBrowserBackup(JSONSerialization.data(withJSONObject: missing))
            preconditionFailure("missing-image restore must fail")
        } catch MemoWeaverAttachments.Problem.missingAsset { }
        try check(try cleanDB.notes().isEmpty, "missing-image failure rolls back")
        try FileManager.default.removeItem(at: MemoWeaverAttachments.folder(in: directory))
        do { _ = try db.exportBrowserCompatibleJSON(); preconditionFailure("missing-image export must fail") }
        catch MemoWeaverAttachments.Problem.missingAsset { }
        let long = String(repeating: "한글🌍", count: 2000) + " UNIQUEENDMARKER"
        _ = try db.addArchive(id: "long", name: "long.txt", content: long)
        let chunks = try db.archiveChunks()
        check(WorkOSSearch.find(question: "UNIQUEENDMARKER", notes: [], chunks: chunks).count == 1, "long-line tail is searchable")
        // Simulate the historical truncation and verify repair keeps chunk ID.
        let oldID = chunks.first!.id
        var handle: OpaquePointer?
        sqlite3_open(db.databaseURL.path, &handle)
        sqlite3_exec(handle, "UPDATE chunks SET content=substr(content,1,3500)", nil, nil, nil)
        sqlite3_close(handle)
        try db.repairTruncatedArchiveChunks()
        let repaired = try db.archiveChunks()
        check(repaired.first?.id == oldID && repaired.first?.text == long, "old truncated index repaired without losing IDs")
        print("PASS: welcome once, metadata history, wiki rename/code/line/backup, image completeness rollback, long-line search and existing-index repair")
    }
}
