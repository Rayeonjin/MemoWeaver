import Foundation
import SQLite3

@main
struct ReferenceWorkspaceV0915Smoke {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MW-0915-" + UUID().uuidString)
        let restored = FileManager.default.temporaryDirectory.appendingPathComponent("MW-0915-B-" + UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: restored)
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        // An old v0.9.14 database contains a 4-column memory_links table.
        var handle: OpaquePointer?
        assert(sqlite3_open(root.appendingPathComponent("WorkOS.sqlite").path, &handle) == SQLITE_OK)
        assert(sqlite3_exec(handle, "CREATE TABLE memory_links (link_key TEXT PRIMARY KEY, first_id TEXT NOT NULL, second_id TEXT NOT NULL, created_at TEXT NOT NULL)", nil, nil, nil) == SQLITE_OK)
        assert(sqlite3_exec(handle, "INSERT INTO memory_links VALUES ('note:old|note:other','note:old','note:other','2026-01-01')", nil, nil, nil) == SQLITE_OK)
        sqlite3_close(handle)

        let db = try LocalDatabase(directoryOverride: root)
        let old = try db.confirmedLinks()
        assert(old.count == 1 && old[0].relationKind == "related" && old[0].memo == "")
        let a = try db.createNote(typeID: "type-note", markdown: true)
        let b = try db.createNote(typeID: "type-note", markdown: true)
        let savedA = try db.saveNote(a, title: "현재 메모", bodyHTML: "# 작성 중\n중요한 판단", typeID: a.typeID,
            bookID: "", noteDate: "2026-01-01", status: "진행 중", sourceURL: "",
            pinned: false, archived: false, checkpoint: false)
        let savedB = try db.saveNote(b, title: "과거 메모", bodyHTML: "# 예전 내용\n자료 인용", typeID: b.typeID,
            bookID: "", noteDate: "2024-01-01", status: "진행 중", sourceURL: "",
            pinned: false, archived: false, checkpoint: false)
        let idA = "note:" + savedA.id
        let idB = "note:" + savedB.id
        try db.upsertMemoryLink(MemoryLink(idA, idB, relationKind: "supports", memo: "판단 근거로 사용"))
        let typed = try db.confirmedLinks().first { $0.id == MemoryLink(idA, idB).id }!
        assert(typed.relationKind == "supports" && typed.memo == "판단 근거로 사용")
        try db.addMemoryLink(MemoryLink(idA, idB))
        let afterLegacy = try db.confirmedLinks().first { $0.id == typed.id }!
        assert(afterLegacy.relationKind == "supports" && afterLegacy.memo == "판단 근거로 사용")
        let source = try db.evidenceDocument(entityID: idA)!
        let other = try db.evidenceDocument(entityID: idB)!
        let inferred = MemoryInferredRelation(fromID: idA, toID: idB, relationType: "supports",
            summary: "원문이 연결됨", fromQuote: "중요한 판단", toQuote: "자료 인용",
            fromSignature: source.signature, toSignature: other.signature,
            model: "local", createdAt: WorkOSDate.now())
        let listed = ReferencePanelCore.related(centers: [idA], confirmed: [typed],
            inferred: [inferred], valid: [idA, idB])
        assert(listed.count == 1 && listed[0].id == idB && listed[0].source == "manual")
        let aiOnly = ReferencePanelCore.related(centers: [idA], confirmed: [],
            inferred: [inferred], valid: [idA, idB])
        assert(aiOnly.count == 1 && aiOnly[0].source == "ai")
        let noSemantic = ReferencePanelCore.related(centers: [idA], confirmed: [],
            inferred: [], valid: [idA, idB])
        assert(noSemantic.isEmpty) // raw bge-m3 similarity must never be represented as a link.
        assert(ReferencePanelCore.sanitizeKind("inject") == "related")
        let preview = ReferencePanelCore.limitedText(String(repeating: "내용", count: 10000), maxCharacters: 120)
        assert(preview.text.count == 120 && preview.more)
        assert(ReferencePanelCore.limitedText("짧은 기록", maxCharacters: 120).more == false)
        let searchResult = MemorySource(id: "virtual:abc", kind: "archive", sourceID: "a",
            title: "기억", subtitle: "원본", text: "", fromLine: 1, toLine: 2, score: 5)
        assert(ReferencePanelCore.entityID(for: searchResult) == "virtual:abc")
        let backup = try db.exportBrowserCompatibleJSON()
        let dictionary = try JSONSerialization.jsonObject(with: backup) as! [String: Any]
        let rawLinks = dictionary["memoryLinks"] as! [[String: Any]]
        assert(rawLinks.contains { ($0["memo"] as? String) == "판단 근거로 사용" })
        let newDB = try LocalDatabase(directoryOverride: restored)
        _ = try newDB.importBrowserBackup(backup)
        let newLink = try newDB.confirmedLinks().first { $0.id == typed.id }!
        assert(newLink.relationKind == "supports" && newLink.memo == "판단 근거로 사용")
        let unchanged = try newDB.evidenceDocument(entityID: idA)!
        assert(unchanged.text == source.text)
        try newDB.removeMemoryLink(typed)
        let afterRemoving = try newDB.confirmedLinks()
        assert(afterRemoving.allSatisfy { $0.id != typed.id })
        print("PASS v0.9.15 old DB migration, manual link kind/memo, no downgrade, linked-vs-AI dedup, bounded preview, virtual search ref, JSON restore, original source unchanged")
    }
}
