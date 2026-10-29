import Foundation

@main
struct ReviewStabilitySmoke {
    static func check(_ condition: @autoclosure () throws -> Bool, _ label: String) rethrows {
        let passed = try condition()
        precondition(passed, label)
    }
    static func json(_ raw: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: raw)
    }
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mw-stability-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let db = try LocalDatabase(directoryOverride: root.appendingPathComponent("db"))
        let original = try db.createNote(typeID: "type-note", markdown: true)
        let saved = try db.saveNote(original, title: "원문", bodyHTML: "before <div>한글 🌍</div>",
            typeID: original.typeID, bookID: original.bookID, noteDate: original.noteDate,
            status: original.status, sourceURL: "", pinned: false, archived: false, checkpoint: true)
        let revision = saved.revisions.last!
        check(revision["bodyFormat"] as? String == "markdown", "revision must retain source format")
        check(revision["body"] as? String == saved.bodyHTML, "raw Markdown revision preserved")
        let historyItems = MemoryEngine.items(notes: [saved], chunks: []).filter { $0.id.contains(":revision:") }
        check(historyItems.contains(where: { $0.text.contains("<div>한글 🌍</div>") }), "semantic history retains Markdown source")
        let schedule = WorkScheduleItem.make(noteID: saved.id, title: "테스트 마감", dueDay: "2028-02-29")
        try db.saveScheduleItem(schedule)
        let exported = try db.exportBrowserCompatibleJSON()
        let valid = try JSONSerialization.jsonObject(with: exported) as! [String: Any]
        let existingIDs = try db.notes().map(\.id)
        for key in ["notes", "types", "books", "sources", "events"] {
            var malformed = valid
            let row: [String: Any] = key == "notes" ? ["id":"duplicate", "body":"FIRST"] :
                (key == "sources" ? ["id":"duplicate", "name":"text", "text":"body"] : ["id":"duplicate"])
            var second = row
            if key == "notes" { second["body"] = "SECOND" }
            malformed[key] = [row, second]
            do {
                _ = try db.replaceAllWithVerifiedBrowserBackup(json(malformed))
                preconditionFailure("duplicate \(key) must reject replacement")
            } catch LocalDatabase.Failure.badBackup { }
            try check(try db.notes().map(\.id) == existingIDs, "failed preflight preserves current notes")
            try check(try db.scheduledItems().count == 1, "failed preflight preserves schedule")
        }
        let restored = try db.replaceAllWithVerifiedBrowserBackup(exported)
        check(restored.notes == 1, "valid replacement note count")
        try check(try db.notes().first?.bodyHTML == saved.bodyHTML, "backup source roundtrip")
        try check(try db.scheduledItems().first?.id == schedule.id, "backup schedule roundtrip")
        // Verify a source silently skipped by addArchive also rolls back replace-all.
        var deduplicated = valid
        deduplicated["sources"] = [["id":"source-a","name":"same","text":"same"],
                                   ["id":"source-b","name":"same","text":"same"]]
        do {
            _ = try db.replaceAllWithVerifiedBrowserBackup(json(deduplicated))
            preconditionFailure("partial source replacement must roll back")
        } catch LocalDatabase.Failure.badBackup { }
        try check(try db.notes().map(\.id) == existingIDs, "count mismatch rolls back database")
        let oversized = root.appendingPathComponent("oversized.json")
        FileManager.default.createFile(atPath: oversized.path, contents: nil)
        let handle = try FileHandle(forWritingTo: oversized)
        try handle.truncate(atOffset: UInt64(LocalDatabase.maxJSONBackupBytes))
        try handle.close()
        do {
            _ = try LocalDatabase.readBackupData(from: oversized)
            preconditionFailure("oversize file must reject before reading")
        } catch LocalDatabase.Failure.backupTooLarge { }
        print("PASS: duplicate collections rejected, rollback, JSON/schedule roundtrip, file size preflight")

        var raw = WorkOSJSON.dictionary(saved.rawJSON)
        raw["notebookIds"] = ["book-a", "book-b"]
        raw["bookId"] = "book-a"
        raw["unknownFutureField"] = ["preserved": true]
        var note = WorkNote.from(raw)
        let copy = note
        check(note.notebookIDs == ["book-a", "book-b"], "cached notebook membership")
        raw["notebookIds"] = ["book-a", "book-c"]
        note.rawJSON = try WorkOSJSON.encode(raw)
        check(note.notebookIDs == ["book-a", "book-c"], "raw JSON assignment invalidates cache")
        check(copy.notebookIDs == ["book-a", "book-b"], "value copy cache isolation")
        check(WorkOSJSON.dictionary(note.rawJSON)["unknownFutureField"] != nil, "unknown fields retained")
        check(Set([note, copy]).count == 2, "Hashable respects distinct raw snapshots")
        raw["body"] = String(repeating: "한글 메모 내용 abc\n", count: 5000)
        raw["revisions"] = (0..<50).map { ["id":String($0), "body":raw["body"] as! String] }
        let large = WorkNote.from(raw)
        let started = Date()
        var count = 0
        for _ in 0..<100 { count += large.notebookIDs.count }
        check(count == 200, "large note membership correctness")
        print("PERF: notebookIDs 100 reads, rawJSON=\(large.rawJSON.utf8.count) bytes, \(Date().timeIntervalSince(started)*1000)ms")

        var seoul = Calendar(identifier: .gregorian)
        seoul.timeZone = TimeZone(identifier: "Asia/Seoul")!
        check(WorkOSDate.localDay("2026-10-29T15:30:00.000Z", calendar: seoul) == "2026-10-30", "Seoul midnight UTC conversion")
        var local = Calendar.current.dateComponents([.year,.month,.day], from: Date())
        local.hour = 0; local.minute = 30
        let timestamp = Calendar.current.date(from: local)!
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        raw = WorkOSJSON.dictionary(saved.rawJSON)
        raw["updatedAt"] = formatter.string(from: timestamp)
        raw["noteDate"] = "2000-01-01"
        check(NotesListFilter.matches(WorkNote.from(raw), scope: .today), "today filter uses local update day")
        print("PASS: raw JSON cache invalidation, value semantics, unknown fields, local date filtering")

        let draft = MemoWeaverRecoveryDraft(noteID: "test", storageEpoch: "epoch", baseRevision: "base",
            capturedAt: "now", title: "title", body: "body", typeID: "type", bookID: "book",
            notebookIDs: ["book"], noteDay: "2026-10-29", status: "active", sourceURL: "", pinned: false)
        let encoded = try JSONEncoder().encode(draft)
        for key in ["notebookIDs", "noteDay", "status", "sourceURL"] {
            var changed = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
            changed[key] = key == "notebookIDs" ? ["book", "second"] : "changed"
            let recovered = try JSONDecoder().decode(MemoWeaverRecoveryDraft.self, from: json(changed))
            check(!draft.hasSameContent(as: recovered), "metadata-only recovery: \(key)")
        }
        print("PASS: metadata-only recovery eligibility")
        contextRegression()
    }

    static func contextRegression() {
        let examples = [
            "한글 🌍\nplain\n", "```mermaid\npie title Chart\n A: 1\n```\nafter",
            "~~~mermaid\n---\ntitle: Test\n---\n%% comment\nxychart-beta\nx-axis [A,B]\n~~~",
            "```mermaid\n%% comment\nsequenceDiagram\nA->>B: msg\n```",
            "$$\nx^2\n$$\n\\[\nx\n\\]\n", "```math\nx\n```\n~~~text\n$$\n~~~",
            "```markmap\n# 한글\n```\n", "```mermaid\n---\ntitle: pending\n",
            "```mermaid\nflowchart TD\nA-->B\n```", "a\r\nb\r\n```tex\r\nx\r\n```"
        ]
        for source in examples {
            let cache = MarkdownContextCache()
            for offset in 0...(source as NSString).length {
                check(cache.context(in: source, utf16Offset: offset) == MarkdownContextCore.context(in: source, utf16Offset: offset), "context parity offset \(offset)")
            }
            for offset in stride(from: (source as NSString).length, through: 0, by: -1) {
                check(cache.context(in: source, utf16Offset: offset) == MarkdownContextCore.context(in: source, utf16Offset: offset), "backward caret parity")
            }
        }
        var source = examples.joined(separator: "\n")
        let cache = MarkdownContextCache()
        var seed: UInt64 = 12345
        func next(_ maxValue: Int) -> Int {
            seed = seed &* 6364136223846793005 &+ 1
            return Int((seed >> 32) % UInt64(maxValue))
        }
        let inserts = ["한글", "🌍", "\n", "```", "$$", "\\[", "~~~", "---", "pie", "sequenceDiagram", ""]
        for _ in 0..<250 {
            let chars = Array(source)
            let start = next(chars.count + 1)
            let length = min(next(5), chars.count - start)
            let prefix = String(chars.prefix(start))
            let removed = String(chars.dropFirst(start).prefix(length))
            let range = NSRange(location: (prefix as NSString).length, length: (removed as NSString).length)
            cache.invalidate(fromUTF16: range.location)
            source = (source as NSString).replacingCharacters(in: range, with: inserts[next(inserts.count)])
            for _ in 0..<12 {
                let offset = next((source as NSString).length + 1)
                check(cache.context(in: source, utf16Offset: offset) == MarkdownContextCore.context(in: source, utf16Offset: offset), "edited context parity")
            }
        }
        let longSource = String(repeating: "한글 메모 🌍\n", count: 12000)
        let longCache = MarkdownContextCache()
        _ = longCache.context(in: longSource, utf16Offset: (longSource as NSString).length)
        let baseline = longCache.scannedLineCount
        for i in 0..<200 {
            _ = longCache.context(in: longSource, utf16Offset: (longSource as NSString).length - (i % 100))
        }
        check(longCache.scannedLineCount - baseline == 200, "caret movement must not reparse full prefix")
        print("PASS: context parity, 250 Unicode edits, 12,000-line caret cache (200 moves / 200 partial lines)")
    }
}
