import AppKit

@MainActor enum EditorImprovementsNativeChecks {
    static func run() throws {
        let pump = UsabilityNativeSmoke.pump
        let prefix = "```swift\n" + String(repeating: "let value = 1\n", count: 500)
        let literal = "# literal\n- [ ] literal\n"
        let full = prefix + literal + "```\n# heading\n"
        let visible = NSRange(location: (prefix as NSString).length, length: (literal as NSString).length)
        precondition(MarkdownEditorHighlightCore.spans(in: full, range: visible).isEmpty)
        for opener in ["$$", "\\["] {
            let closer = opener == "$$" ? "$$" : "\\]"
            let source = opener + "\n" + String(repeating: "x = y\n", count: 500) + literal + closer
            let range = (source as NSString).range(of: literal)
            precondition(MarkdownEditorHighlightCore.spans(in: source, range: range).isEmpty)
        }
        precondition(MarkdownEditorHighlightCore.spans(in: full).contains { $0.kind == .heading })
        let table = "앞말\n| 이름 | 코드 | 상태 |\n| :--- | ---: | --- |\n| 한글😀 | `a|b` | x\\|y |\n뒷말"
        let caret = (table as NSString).range(of: "한글").location
        for action in MarkdownTableEditingCore.Action.allCases {
            guard let result = MarkdownTableEditingCore.change(in: table, selection: NSRange(location: caret, length: 0), action: action) else { fatalError("table action unavailable") }
            let updated = (table as NSString).replacingCharacters(in: result.range, with: result.source)
            precondition(updated.hasPrefix("앞말\n") && updated.hasSuffix("\n뒷말"))
            if action != .deleteRow { precondition(updated.contains("`a|b`") && updated.contains("x\\|y")) }
        }
        for fence in ["```", "~~~~", "$$", "\\["] {
            let source = fence + "\n" + table
            precondition(MarkdownTableEditingCore.change(in: source, selection: NSRange(location: (source as NSString).range(of: "한글").location, length: 0), action: .align) == nil)
        }
        let crlf = table.replacingOccurrences(of: "\n", with: "\r\n")
        let aligned = MarkdownTableEditingCore.change(in: crlf, selection: (crlf as NSString).range(of: "한글"), action: .align)!
        precondition(aligned.source.contains("\r\n") && aligned.source.hasSuffix("\r"))
        let window = NSWindow(contentRect: NSRect(x: 50, y: 50, width: 650, height: 420), styleMask: [.titled], backing: .buffered, defer: false)
        let editor = WorkOSMarkdownTextView(frame: NSRect(x: 0, y: 0, width: 650, height: 420))
        editor.isRichText = false; editor.allowsUndo = true
        window.contentView = editor; window.makeKeyAndOrderFront(nil); window.makeFirstResponder(editor)
        defer { window.orderOut(nil) }
        for action in MarkdownTableEditingCore.Action.allCases {
            editor.string = table; editor.undoManager?.removeAllActions()
            editor.setSelectedRange(NSRange(location: caret, length: 0))
            let item = NSMenuItem(); item.tag = action.rawValue
            editor.editMarkdownTable(item); pump(0.02)
            let edited = editor.string
            precondition(edited != table)
            editor.undoManager?.undo(); precondition(editor.string == table, "table undo lost Korean source")
            editor.undoManager?.redo(); precondition(editor.string == edited)
        }
        editor.string = "현재 본문 한글😀"; editor.undoManager?.removeAllActions()
        let before = editor.string
        precondition(editor.replaceSourceUndoably("이전 본문 한글", range: NSRange(location: 0, length: (before as NSString).length)))
        pump(0.02); editor.undoManager?.undo(); precondition(editor.string == before)
        editor.undoManager?.redo(); precondition(editor.string == "이전 본문 한글")
        editor.setMarkedText("ㅎ", selectedRange: NSRange(location: 1, length: 0), replacementRange: editor.selectedRange())
        let marked = editor.string
        precondition(editor.hasMarkedText())
        precondition(!editor.replaceSourceUndoably("삭제되면 안 됨", range: NSRange(location: 0, length: (marked as NSString).length)))
        precondition(editor.string == marked && editor.hasMarkedText())
        precondition(!MemoWeaverLayoutSwitchSafety.prepare(editor: editor))
        editor.unmarkText()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mw-editor-images-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        editor.imageStorageDirectory = directory
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 64, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        memset(bitmap.bitmapData!, 128, bitmap.bytesPerRow * bitmap.pixelsHigh)
        let png = bitmap.representation(using: .png, properties: [:])!
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setData(png, forType: .png)
        editor.string = "이미지 앞 "; editor.undoManager?.removeAllActions()
        editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
        let original = editor.string
        precondition(editor.beginImageImport(board, at: nil))
        let deadline = Date().addingTimeInterval(5)
        while !editor.string.contains("attachments/") && Date() < deadline { pump(0.01) }
        precondition(editor.string.contains("attachments/"), "async image not inserted")
        pump(0.02); editor.undoManager?.undo(); precondition(editor.string == original)
        editor.undoManager?.redo(); precondition(editor.string.contains("attachments/"))
        let existing = try FileManager.default.contentsOfDirectory(atPath: MemoWeaverAttachments.folder(in: directory).path)
        var canceled = false
        editor.reportImageImportError = { _ in canceled = true }
        precondition(editor.beginImageImport(board, at: nil))
        editor.insertText("수정", replacementRange: editor.selectedRange()); editor.didChangeText()
        let afterEdit = editor.string
        let cancelDeadline = Date().addingTimeInterval(5)
        while !canceled && Date() < cancelDeadline { pump(0.01) }
        pump(0.1)
        precondition(canceled && editor.string == afterEdit)
        let remaining = try FileManager.default.contentsOfDirectory(atPath: MemoWeaverAttachments.folder(in: directory).path)
        precondition(remaining.count == existing.count)
        // A note/data-generation change also cancels an otherwise unchanged draft.
        canceled = false
        precondition(editor.beginImageImport(board, at: nil))
        editor.canInsertImage = { false }
        let generationDeadline = Date().addingTimeInterval(5)
        while !canceled && Date() < generationDeadline { pump(0.01) }
        precondition(canceled && editor.string == afterEdit)
        editor.canInsertImage = nil
        // Check the actual checkpoint contract used before body restoration.
        let db = try LocalDatabase(directoryOverride: directory.appendingPathComponent("database"))
        var note = try db.createNote(typeID: "type-note", markdown: true)
        func save(_ body: String, checkpoint: Bool) throws {
            note = try db.saveNote(note, title: "history", bodyHTML: body, typeID: note.typeID,
                bookID: "", noteDate: note.noteDate, status: note.status, sourceURL: "", pinned: true,
                archived: false, checkpoint: checkpoint)
        }
        try save("old body", checkpoint: true)
        try save("current body", checkpoint: false)
        try save("current body", checkpoint: true)
        try save("old body", checkpoint: false)
        precondition(note.revisions.contains { WorkOSJSON.string($0, "body") == "current body" })
        precondition(note.bodyHTML == "old body" && note.pinned && note.title == "history")
        print("PASS: viewport fence/math context, escaped/code pipes, Korean/emoji/CRLF table edits, single undo/redo, history replacement, marked-text guards, async image insertion/cancel/cleanup")
    }
}
