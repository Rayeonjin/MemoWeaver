import Foundation

@main
struct VirtualMemorySmoke {
    static func check(_ truth: Bool, _ message: String) {
        if !truth { fatalError("FAIL virtual memory: " + message) }
    }

    static func draft(_ body: String, kind: String = "archive", id: String = "legacy-1") -> [VirtualMemory] {
        let sign = VirtualMemoryCore.signature(body)
        let sourceLines = VirtualMemoryCore.lines(body)
        return VirtualMemoryCore.batches(body).flatMap { batch in
            VirtualMemoryCore.make(source: body, kind: kind, sourceID: id,
                sourceTitle: "오래된 메모", batch: batch, groups: nil, ai: false,
                sourceSignature: sign, sourceLines: sourceLines)
        }
    }

    static func main() throws {
        let source = """
        첫 메모\n거래량과 유동성 테스트\n\n오늘 회의 준비\n- 목록 1\n- 목록 2\n\n```mermaid\ngraph LR\nA --> B\n```\n\n$$\na+b=c\n$$\n\n붙여 넣은 자료\n항목\t값\n거래량\t100\n기록 끝 😊
        """
        let fragments = draft(source)
        check(VirtualMemoryCore.valid(fragments, source: source, kind: "archive", id: "legacy-1"), "contiguous coverage")
        check(fragments.map { VirtualMemoryCore.sourceText(source, from: $0.fromLine, to: $0.toLine) }.joined(separator: "\n") == source, "byte-exact text reconstruction")
        let lines = VirtualMemoryCore.lines(source)
        let fenced = lines.firstIndex(of: "```mermaid")! + 1
        let fencedEnd = lines.firstIndex(of: "```")! + 1
        let mathStart = lines.firstIndex(of: "$$")! + 1
        let mathEnd = lines.lastIndex(of: "$$")! + 1
        check(fragments.contains(where: { $0.fromLine <= fenced && $0.toLine >= fencedEnd }), "fenced code preserved")
        check(fragments.contains(where: { $0.fromLine <= mathStart && $0.toLine >= mathEnd }), "math preserved")
        check(!VirtualMemoryCore.available(fragments[0], source: "변경된 원문"), "stale signature rejected")
        check(VirtualMemoryCore.decodeGroups("{\"groups\":[{\"end\":1,\"title\":\"메모\",\"category\":\"record\"}]}", blockCount: 1)?.count == 1, "valid AI JSON")
        check(VirtualMemoryCore.decodeGroups("{\"groups\":[{\"end\":77,\"title\":\"가짜\",\"category\":\"record\"}]}", blockCount: 2) == nil, "out-of-range AI JSON rejected")
        check(VirtualMemoryCore.decodeGroups("{\"groups\":[{\"end\":1,\"title\":\"가짜\",\"category\":\"record\"}]}", blockCount: 2) == nil, "incomplete AI JSON rejected")
        check(VirtualMemoryCore.decodeGroups("{\"groups\":[{\"end\":2,\"title\":\"가짜\",\"category\":\"deleted\"}]}", blockCount: 2) == nil, "unknown AI category rejected")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MemoryHomeVirtualSmoke-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let db = try LocalDatabase(directoryOverride: root)
        check(try db.addArchive(id: "legacy-1", name: "오래된 작업 메모.txt", content: source), "archive added")
        try db.saveVirtualMemories(fragments, source: source, kind: "archive", id: "legacy-1")
        check(try db.virtualMemories().count == fragments.count, "segment persistence")
        check(try db.archiveText(id: "legacy-1") == source, "archive original untouched")
        let windowsText = "첫 줄\r\n둘째 줄\r\n셋째 줄"
        check(try db.addArchive(id: "windows-lines", name: "windows.txt", content: windowsText), "CRLF archive added")
        check(try db.archives().first(where: { $0.id == "windows-lines" })?.lineCount == 3,
              "Windows CRLF physical line count")
        check(try db.archiveChunks().filter { $0.sourceID == "windows-lines" }.last?.toLine == 3,
              "Windows CRLF index line coordinates")
        let indexItems = MemoryEngine.items(notes: [], chunks: try db.archiveChunks().filter { $0.sourceID == "legacy-1" },
            virtualMemories: try db.virtualMemories(), virtualSourceTexts: ["archive:legacy-1":source])
        check(indexItems.count == fragments.count, "replaces generic overlapping archive chunks")
        check(indexItems.allSatisfy { $0.kind == "virtual" && $0.entityID.hasPrefix("virtual:") }, "independent entities")
        // This short fixture fits in one automatic batch. Simulate two valid
        // AI-proposed regions to test that the map actually links *distinct*
        // virtual entities rather than two windows of one entity.
        let atoms = VirtualMemoryCore.blocks(source)
        check(atoms.count >= 2, "multiple safe atoms available")
        let distinct = VirtualMemoryCore.make(source: source, kind: "archive", sourceID: "legacy-1",
            sourceTitle: "오래된 메모", batch: VirtualMemoryBatch(blocks: atoms),
            groups: [VirtualMemoryAIGroup(endBlock: 1, title: "처음 발견", category: "record"),
                     VirtualMemoryAIGroup(endBlock: atoms.count, title: "나중 발견", category: "record")],
            ai: true, sourceSignature: VirtualMemoryCore.signature(source))
        check(VirtualMemoryCore.valid(distinct, source: source, kind: "archive", id: "legacy-1"),
              "AI-proposed split covers original exactly")
        let demoVectors = distinct.map { segment in
            MemoryVector(id: "virtual:" + segment.id + ":part:0", entityID: "virtual:" + segment.id,
                kind: "virtual", title: segment.title, signature: segment.sourceSignature,
                values: [1.0, 0.0], fromLine: segment.fromLine, toLine: segment.toLine)
        }
        let graph = MemoryEngine.graph(notes: [], archives: try db.archives(),
            virtualMemories: distinct, vectors: demoVectors, confirmed: [],
            threshold: 0.8, maxNodes: 25)
        check(graph.nodes.contains(where: { $0.kind == "virtual" }), "memory map contains virtual nodes")
        check(graph.edges.contains(where: { $0.first.hasPrefix("virtual:") && $0.second.hasPrefix("virtual:") }),
              "memory map connects virtual entities by embedding similarity")
        if let firstItem = indexItems.first {
            try db.saveMemoryVector(item: firstItem, model: "bge-m3", vector: [1.0, 0.0])
            check(try db.memoryVectors().contains(where: { $0.id == firstItem.id }), "virtual embeddings persist")
            try db.saveVirtualMemories(fragments, source: source, kind: "archive", id: "legacy-1")
            check(try !db.memoryVectors().contains(where: { $0.id == firstItem.id }),
                  "re-analysis invalidates derived embeddings when labels change")
        }
        let found = WorkOSSearch.find(question: "유동성", notes: [], chunks: try db.archiveChunks(),
            virtualMemories: fragments, virtualSourceTexts: ["archive:legacy-1":source])
        check(found.contains(where: { $0.id.hasPrefix("virtual:") && $0.fromLine > 0 }), "search returns virtual source pointers")
        // Reject an invalid update without losing previously generated labels.
        var broken = fragments
        broken[0].fromLine = 5
        do {
            try db.saveVirtualMemories(broken, source: source, kind: "archive", id: "legacy-1")
            fatalError("invalid coverage accepted")
        } catch { }
        check(try db.virtualMemories().count == fragments.count, "invalid replacement leaves index intact")
        let exported = try db.exportBrowserCompatibleJSON()
        check(String(decoding: exported, as: UTF8.self).contains("virtualSegments"), "JSON backup includes virtual metadata")
        let restoredDir = FileManager.default.temporaryDirectory.appendingPathComponent("MemoryHomeVirtualRestore-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: restoredDir) }
        let restored = try LocalDatabase(directoryOverride: restoredDir)
        _ = try restored.importBrowserBackup(exported)
        check(try restored.archiveText(id: "legacy-1") == source, "backup restores intact source")
        check(try restored.virtualMemories().count == fragments.count, "backup restores verified pointers")
        try db.removeVirtualMemories(kind: "archive", id: "legacy-1")
        check(try db.virtualMemories().isEmpty, "remove only derived pointers")
        check(try db.archiveText(id: "legacy-1") == source, "remove does not erase source")

        let originalNote = try db.createNote(typeID: "type-note", markdown: true)
        let noteText = "# 기록\n첫 관찰\n둘째 생각 😺\n\n- 세부 의견\n  - 보충 내용"
        let savedNote = try db.saveNote(originalNote, title: "오래된 생각", bodyHTML: noteText,
            typeID: originalNote.typeID, bookID: "", noteDate: WorkOSDate.day(),
            status: "진행 중", sourceURL: "", pinned: false, archived: false, checkpoint: false)
        let noteParts = draft(noteText, kind: "note", id: savedNote.id)
        try db.saveVirtualMemories(noteParts, source: noteText, kind: "note", id: savedNote.id)
        check(try db.notes().first(where: { $0.id == savedNote.id })?.bodyHTML == noteText, "note original unchanged")
        let noteIndex = MemoryEngine.items(notes: [savedNote], chunks: [], virtualMemories: noteParts,
            virtualSourceTexts: ["note:" + savedNote.id: noteText])
        check(noteIndex.contains(where: { $0.kind == "virtual" && $0.sourceKind == "note" }), "note virtual entity searchable")
        let noteBackup = try db.exportBrowserCompatibleJSON()
        let noteRestoreDir = FileManager.default.temporaryDirectory.appendingPathComponent("MemoryHomeNoteRestore-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: noteRestoreDir) }
        let noteRestore = try LocalDatabase(directoryOverride: noteRestoreDir)
        _ = try noteRestore.importBrowserBackup(noteBackup)
        check(try noteRestore.virtualMemories().contains(where: { $0.sourceKind == "note" && $0.sourceID == savedNote.id }), "note pointer survives backup roundtrip")
        let changedNoteText = noteText + "\n나중에 덧붙임"
        _ = try db.saveNote(savedNote, title: "오래된 생각", bodyHTML: changedNoteText,
            typeID: originalNote.typeID, bookID: "", noteDate: WorkOSDate.day(),
            status: "진행 중", sourceURL: "", pinned: false, archived: false, checkpoint: false)
        check(!VirtualMemoryCore.available(noteParts[0], source: changedNoteText), "edited note pointers are invalid")

        // Deliberately unstructured 10k-line legacy note. Check full coverage,
        // stable positional IDs, memory bounds and one-based last line.
        let big = (1...10000).map { n in
            n.isMultiple(of: 97) ? "# 갑자기 등장한 제목 \(n)" :
                (n.isMultiple(of: 29) ? "임시 복사\t가나다\t\(n)" : "생각나는 대로 붙여 쓴 기록 \(n) 😊")
        }.joined(separator: "\n")
        let bigParts = draft(big)
        check(bigParts.count > 30, "large file separated into many units")
        check(VirtualMemoryCore.valid(bigParts, source: big, kind: "archive", id: "legacy-1"), "10k-line coverage")
        check(bigParts.last?.toLine == 10000, "line 10000 is retrievable")
        check(bigParts.map { $0.id } == draft(big).map { $0.id }, "stable identifiers")
        print("PASS virtual memory: exact line coverage, protected markdown, AI JSON rejection, SQLite transactions, search, semantic items, backup roundtrip, stale revision, 10000-line fixture (\(bigParts.count) segments)")
    }
}
