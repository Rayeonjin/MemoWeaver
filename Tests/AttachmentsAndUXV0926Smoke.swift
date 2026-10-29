import Foundation

@main
struct AttachmentsAndUXV0926Smoke {
    static func check(_ value: @autoclosure () -> Bool, _ detail: String) {
        if !value() { fputs("FAIL: \(detail)\n", stderr); exit(1) }
    }

    static func main() throws {
        let grid = MarkdownTableGridCore.insertion(columns: 3, rows: 4)
        check(grid.source.components(separatedBy: "\n").filter { !$0.isEmpty }.count == 5,
              "3x4 grid has header + separator + three body rows")
        check(grid.source.contains("| 열 1 | 열 2 | 열 3 |"), "Korean table headers")
        check((grid.source as NSString).length > grid.caretBack, "Caret is inside generated table")
        check(MarkdownTableGridCore.insertion(columns: 10, rows: 100).source.contains("열 8"),
              "Grid dimension upper bounds")
        for kind in MermaidDiagramTemplates.Kind.allCases {
            let source = MermaidDiagramTemplates.insertion(for: kind).source
            check(source.hasPrefix("```mermaid\n") && source.hasSuffix("```\n"), "Valid fenced diagram")
            let position = (source as NSString).length - 5
            let actual = MarkdownContextCore.context(in: source, utf16Offset: position)
            let expected: MarkdownEditingContext = kind == .gantt ? .mermaidGantt :
                kind == .timeline ? .mermaidTimeline : .mermaidSequence
            check(actual == expected, "Dialect detection: \(kind.rawValue)")
            check(MarkdownPreviewCore.render(source).html.contains("data-workos-diagram='mermaid'"),
                  "Official Mermaid wrapper for \(kind.rawValue)")
        }
        check(MarkdownAssistSnippet.ganttTask.context == .mermaidGantt, "Gantt toolbar")
        check(MarkdownAssistSnippet.timelineEvent.context == .mermaidTimeline, "Timeline toolbar")
        check(MarkdownAssistSnippet.sequenceMessage.context == .mermaidSequence, "Sequence toolbar")

        let png = Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aKx8AAAAASUVORK5CYII=")!
        let storage = FileManager.default.temporaryDirectory
            .appendingPathComponent("MW-v0926-" + UUID().uuidString)
        let export = FileManager.default.temporaryDirectory
            .appendingPathComponent("MW-export-v0926-" + UUID().uuidString)
        let restored = FileManager.default.temporaryDirectory
            .appendingPathComponent("MW-restore-v0926-" + UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: storage)
            try? FileManager.default.removeItem(at: export)
            try? FileManager.default.removeItem(at: restored)
        }
        try FileManager.default.createDirectory(at: export, withIntermediateDirectories: true)
        let path = try MemoWeaverAttachments.storePNG(png, in: storage)
        check(MemoWeaverAttachments.validRelativePath(path), "Only UUID paths")
        check(MemoWeaverAttachments.read(path, in: storage) == png, "Saved immutable PNG")
        check(MemoWeaverAttachments.read("../secrets", in: storage) == nil, "No traversal")
        let snippet = "![진행 화면](\(path))"
        let rendered = MarkdownPreviewCore.render(snippet).html
        check(rendered.contains("data-mw-attachment"), "Safe image placeholder")
        check(!rendered.contains("data:image/png"), "Core never reads files")
        let complete = MemoWeaverAttachments.resolvePreviewImages(rendered, storageDirectory: storage)
        check(complete.contains("data:image/png;base64,"), "Self-contained image preview")
        check(complete.contains("진행 화면"), "Korean alt text")
        let noNetwork = MarkdownPreviewCore.render("![unsafe](https://danger.example/image.png)").html
        check(!noNetwork.contains("<img"), "Untrusted network image never loads")
        let fake = MarkdownPreviewCore.render("![unsafe](file:///etc/passwd)").html
        check(!fake.contains("<img"), "Untrusted file image never loads")
        let injection = MarkdownPreviewCore.render("![\"<script>](\(path))").html
        check(!injection.contains("<script>"), "Malicious alt is escaped")
        try MemoWeaverAttachments.exportMarkdownAssets(from: snippet, to: export, storageDirectory: storage)
        let exportedPNG = try Data(contentsOf: export.appendingPathComponent(path))
        check(exportedPNG == png, "Portable Markdown asset")
        let backed = try MemoWeaverAttachments.backupEntries(in: storage)
        check(backed.count == 1, "JSON base64 attachment")
        let verified = try MemoWeaverAttachments.validatedBackupEntries(backed)
        let added = try MemoWeaverAttachments.installBackupEntries(verified, in: restored)
        check(added.count == 1 && MemoWeaverAttachments.read(path, in: restored) == png,
              "JSON restore attachment")
        var invalid = backed
        invalid[0]["path"] = "../../outside.png"
        check((try? MemoWeaverAttachments.validatedBackupEntries(invalid)) == nil,
              "Tampered backup rejected")
        check((try? MemoWeaverAttachments.storePNG(Data("text".utf8), in: storage)) == nil,
              "Invalid binary rejected")
        var oversizedCanvas = png
        oversizedCanvas.replaceSubrange(16..<24, with: [0, 1, 0, 0, 0, 1, 0, 0])
        check(!MemoWeaverAttachments.pngIsValid(oversizedCanvas), "PNG decompression bomb refused")
        check(!MemoWeaverAttachments.pngIsValid(png.prefix(24)), "Truncated PNG header refused")

        let database = try LocalDatabase(directoryOverride: storage)
        let created = try database.createNote(typeID: "type-note", markdown: true)
        _ = try database.saveNote(created, title: "이미지 테스트", bodyHTML: snippet,
            typeID: created.typeID, bookID: created.bookID,
            noteDate: created.noteDate, status: created.status, sourceURL: "",
            pinned: false, archived: false, checkpoint: true)
        let json = try database.exportBrowserCompatibleJSON()
        let raw = try JSONSerialization.jsonObject(with: json) as! [String: Any]
        check((raw["attachments"] as? [[String: String]])?.count == 1,
              "Full JSON export includes PNG bytes")
        let newDB = try LocalDatabase(directoryOverride: restored)
        let imported = try newDB.replaceAllWithBrowserBackup(json)
        check(imported.notes == 1 && MemoWeaverAttachments.read(path, in: restored) == png,
              "Full JSON restore includes PNG")
        let snapshot = try database.snapshotBackupIfNeeded(force: true)
        let companion = MemoWeaverAttachments.backupCompanionDirectory(for: snapshot)
        check(FileManager.default.fileExists(atPath: companion.appendingPathComponent(
            String(path.dropFirst("attachments/".count))).path), "SQLite snapshot companion PNG")
        print("PASS v0.9.26: table grid, three diagram dialects, image security/preview, MD export, JSON restore, SQLite snapshot")
    }
}
