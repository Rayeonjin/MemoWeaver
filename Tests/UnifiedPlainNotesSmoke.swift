import Foundation

@main
struct UnifiedPlainNotesSmoke {
    static func main() throws {
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
        }
        let originalHTML = """
        <html><head><style>p.p1{font: 13px Arial;} span.s1{color: #000}</style></head>
        <body><p class="p1"># 업무 메모</p><p class="p1">    - [ ] 확인</p>
        <p class="p1">중요 &amp; 테스트 &lt;A&gt; &#x1F642;</p></body></html>
        """
        let old = WorkNote.from([
            "id":"historic-note", "title":"", "body":originalHTML,
            "customDoNotDiscard":"retained", "revisions":[["at":"2025-01-01T00:00:00Z", "body":"<p>old</p>"]],
            "workosBlocks":[["id":"tbl1", "kind":"table", "source":"| Col | Num |\n| --- | --- |\n| a | 7 |"],
                            ["id":"m1", "kind":"equation", "source":"E=mc^2"],
                            ["id":"d1", "kind":"mermaid", "source":"flowchart TD\n  A --> B"]]
        ])
        check(!old.isMarkdown, "Old note format must remain HTML on read")
        let converted = LegacyNoteTextConverter.editableText(for: old)
        check(converted.contains("# 업무 메모") && converted.contains("    - [ ] 확인"), "Markdown punctuation / indentation lost")
        check(converted.contains("중요 & 테스트 <A> 🙂"), "Unicode or HTML entities damaged")
        check(!converted.contains("p.p1") && !converted.contains("<head"), "CSS leaked into editor")
        check(converted.contains("| Col | Num |") && converted.contains("$$\nE=mc^2\n$$") &&
              converted.contains("```mermaid"), "Old extension blocks not visible as source")
        check(old.bodyHTML == originalHTML && !old.isMarkdown, "Read-only display conversion mutated note")
        check(NoteDocuments.markdown(note: old) == converted, "Legacy .md export differs from editor")
        // Retiring the old bottom UI must not hide or discard its data.
        let preview = MarkdownPreviewCore.render(converted).html
        check(preview.contains("workos-table") && preview.contains("formula") &&
              preview.contains("diagram"), "Legacy bottom blocks missing from Markdown preview")
        check(LegacyNoteTextConverter.text(from: "# Hello\n\tindent\n") == "# Hello\n\tindent\n", "Plain source should be byte-for-byte preserved")
        check(LegacyNoteTextConverter.text(from: "<p>A &amp; B</p><p>C &lt; D</p>") == "A & B\nC < D", "HTML paragraph decoding wrong")
        check(LegacyNoteTextConverter.text(from: "<p><a href=\"https://local.example/path?a=1&amp;b=2\">사이트</a></p>") ==
              "[사이트](https://local.example/path?a=1&b=2)", "Link destination lost")
        let simpleTable = LegacyNoteTextConverter.text(from: "<table><tr><th>업무</th><th>상태</th></tr><tr><td>점검</td><td>완료</td></tr></table>")
        check(simpleTable.contains("| 업무 | 상태 |") && simpleTable.contains("| 점검 | 완료 |"), "Existing HTML table should become Markdown")
        check(LegacyNoteTextConverter.containsComplexContent("<img src='private.png'>"), "Nontext warning missing")

        let scratchText = "  # 오늘의 기록\n\n\t- [x] 완료\n"
        let scratch = WorkNote.from(["id":"old-txt", "body":WorkOSQuickCapture.html(scratchText),
                                     "quickCaptureText":scratchText, "quickCaptureDay":"2025-07-01"])
        check(LegacyNoteTextConverter.editableText(for: scratch) == scratchText, "Original quick capture text changed")
        check(WorkNote.make(typeID: "type-meeting", markdown: true).bodyHTML.contains("## 회의 목적"), "New meeting template missing")
        check(WorkNote.make(typeID: "type-task", markdown: true).bodyHTML.contains("- [ ]"), "New task template missing")

        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("UnifiedNotes-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let db = try LocalDatabase(directoryOverride: tmp)
        // This uses an old DB record, with no new schema and all unknown JSON fields.
        let new = try db.createNote(typeID: "type-note", markdown: false)
        let archived = try db.saveNote(new, title: "", bodyHTML: originalHTML,
                                       typeID: new.typeID, bookID: new.bookID, noteDate: new.noteDate,
                                       status: new.status, sourceURL: new.sourceURL, pinned: new.pinned,
                                       archived: false, checkpoint: true)
        var raw = WorkOSJSON.dictionary(archived.rawJSON)
        raw["customDoNotDiscard"] = "retained"
        raw["workosBlocks"] = WorkBlock.encode(old.workosBlocks)
        // Bring in a prior-version backup, rather than changing a real user DB.
        let supplied = try WorkOSJSON.encode(raw)
        let jsonData = try db.exportBrowserCompatibleJSON()
        var backup = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        var notes = backup["notes"] as! [[String: Any]]
        if let i = notes.firstIndex(where: { ($0["id"] as? String) == new.id }) {
            notes[i] = WorkOSJSON.dictionary(supplied)
        } else { preconditionFailure("missing test record") }
        backup["notes"] = notes
        let importedJSON = try JSONSerialization.data(withJSONObject: backup)
        // Test the legacy restore round-trip on an isolated database.
        let importedDir = tmp.appendingPathComponent("Imported")
        let importedDB = try LocalDatabase(directoryOverride: importedDir)
        _ = try importedDB.importBrowserBackup(importedJSON)
        let prior = try importedDB.notes().first(where: { $0.id == new.id })!
        check(!prior.isMarkdown && prior.bodyHTML == originalHTML, "Restore altered original legacy body")
        let display = LegacyNoteTextConverter.editableText(for: prior)
        let afterView = try importedDB.notes().first(where: { $0.id == new.id })!
        check(!afterView.isMarkdown && afterView.bodyHTML == originalHTML, "Opening legacy note writes unexpectedly")
        // A metadata-only save must keep legacy format, even though it was opened in the editor.
        let metaOnly = try importedDB.saveNote(afterView, title: "회의 중", bodyHTML: afterView.bodyHTML,
                                               typeID: afterView.typeID, bookID: afterView.bookID,
                                               noteDate: afterView.noteDate, status: afterView.status,
                                               sourceURL: afterView.sourceURL, pinned: afterView.pinned,
                                               archived: false, checkpoint: false)
        check(!metaOnly.isMarkdown && metaOnly.bodyHTML == originalHTML, "Metadata edit migrated HTML")
        let changed = display + "\n추가한 메모"
        let updated = try importedDB.saveNote(metaOnly, title: metaOnly.title, bodyHTML: changed,
                                             typeID: metaOnly.typeID, bookID: metaOnly.bookID,
                                             noteDate: metaOnly.noteDate, status: metaOnly.status,
                                             sourceURL: metaOnly.sourceURL, pinned: metaOnly.pinned,
                                             archived: false, checkpoint: true,
                                             convertLegacyBodyToMarkdown: true)
        check(updated.id == prior.id && updated.isMarkdown && updated.bodyHTML == changed, "Migration source mismatch")
        let upgraded = WorkOSJSON.dictionary(updated.rawJSON)
        check(upgraded["legacyOriginalHTML"] as? String == originalHTML, "Original HTML not archived")
        check((upgraded["legacyOriginalWorkosBlocks"] as? [[String: Any]])?.count == 3, "Old blocks not archived")
        check(updated.workosBlocks.isEmpty, "Old extension blocks must not be rendered twice")
        check(upgraded["customDoNotDiscard"] as? String == "retained", "Unknown JSON key discarded")
        check(updated.revisions.count >= 1, "Revisions lost")
        let backupFolder = importedDir.appendingPathComponent("Backups")
        let snapshots = try FileManager.default.contentsOfDirectory(at: backupFolder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "sqlite" }
        check(!snapshots.isEmpty, "No pre-conversion snapshot made")
        let restoreDir = tmp.appendingPathComponent("FromSnapshot")
        try FileManager.default.createDirectory(at: restoreDir, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: snapshots[0], to: restoreDir.appendingPathComponent("WorkOS.sqlite"))
        let snapshotDB = try LocalDatabase(directoryOverride: restoreDir)
        let backedUp = try snapshotDB.notes().first(where: { $0.id == updated.id })!
        check(!backedUp.isMarkdown && backedUp.bodyHTML == originalHTML, "Snapshot does not contain original")
        let reopen = try LocalDatabase(directoryOverride: importedDir)
        let roundTrip = try reopen.notes().first(where: { $0.id == updated.id })!
        check(roundTrip.isMarkdown && roundTrip.bodyHTML == changed &&
              WorkOSQuickCapture.plainText(roundTrip) == changed &&
              roundTrip.plainBody.contains("추가한 메모"), "Reload/FTS index roundtrip failed")
        let exported = try reopen.exportBrowserCompatibleJSON()
        let exportDict = try JSONSerialization.jsonObject(with: exported) as! [String: Any]
        let exportNote = (exportDict["notes"] as! [[String: Any]]).first(where: { ($0["id"] as? String) == updated.id })!
        check(exportNote["legacyOriginalHTML"] as? String == originalHTML, "JSON export lost legacy archive")

        // Backup failure must abort the migration, not rewrite an old HTML record.
        let failDir = tmp.appendingPathComponent("NoBackup")
        let failDB = try LocalDatabase(directoryOverride: failDir)
        let doomed = try failDB.createNote(typeID: "type-note", markdown: false)
        let before = try failDB.saveNote(doomed, title: "", bodyHTML: "<p>원문</p>",
                                         typeID: doomed.typeID, bookID: doomed.bookID,
                                         noteDate: doomed.noteDate, status: doomed.status,
                                         sourceURL: doomed.sourceURL, pinned: doomed.pinned,
                                         archived: false, checkpoint: false)
        try Data("block Backups folder".utf8).write(to: failDir.appendingPathComponent("Backups"))
        do {
            _ = try failDB.saveNote(before, title: "", bodyHTML: "원문 수정",
                                    typeID: before.typeID, bookID: before.bookID, noteDate: before.noteDate,
                                    status: before.status, sourceURL: before.sourceURL,
                                    pinned: before.pinned, archived: false, checkpoint: false,
                                    convertLegacyBodyToMarkdown: true)
            preconditionFailure("Migration must fail if pre-change backup fails")
        } catch { /* expected failure */ }
        let unchanged = try failDB.notes().first(where: { $0.id == before.id })!
        check(!unchanged.isMarkdown && unchanged.bodyHTML == before.bodyHTML, "Failed migration touched legacy content")
        print("PASS unified v0.9.1: TXT/HTML/CSS/entities/links/tables/blocks; lazy conversion; metadata/no-open writes; WAL snapshot; failed-backup rollback; revisions/unknown JSON/export")
    }
}
