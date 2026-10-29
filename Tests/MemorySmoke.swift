import Foundation

@main
struct MemorySmoke {
    static func main() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkOSMemorySmoke-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let db = try LocalDatabase(directoryOverride: temporaryDirectory)
        let note1 = try db.createNote(typeID: "type-work")
        let note2 = try db.createNote(typeID: "type-work")
        let note3 = try db.createNote(typeID: "type-meeting")
        let alpha = try db.saveNote(note1, title: "API timeout follow-up", bodyHTML: "<p>HTTP timeout regression investigation</p>",
            typeID: "type-work", bookID: "book-engineering", noteDate: WorkOSDate.day(), status: "진행 중",
            sourceURL: "", pinned: true, archived: false, checkpoint: true)
        let beta = try db.saveNote(note2, title: "Backend latency incident", bodyHTML: "<p>Latency after deployment and timeout remediation</p>",
            typeID: "type-work", bookID: "book-engineering", noteDate: WorkOSDate.day(), status: "완료",
            sourceURL: "", pinned: false, archived: false, checkpoint: true)
        let gamma = try db.saveNote(note3, title: "Office chair preference", bodyHTML: "<p>Compare ergonomic desk chairs</p>",
            typeID: "type-meeting", bookID: "book-office", noteDate: WorkOSDate.day(), status: "완료",
            sourceURL: "", pinned: false, archived: false, checkpoint: true)
        let legacyLines = (1...11_005).map { i in i == 10_100 ? "API timeout: deployment latency resolved" : "Archived status log: day \(i)" }
        try db.addArchive(name: "legacy-without-extension", content: legacyLines.joined(separator: "\n"))
        let archive = try db.archives().first!
        let entries = MemoryEngine.items(notes: try db.notes(), chunks: try db.archiveChunks())
        assert(entries.count > 200)
        assert(entries.contains { $0.kind == "archive" && $0.fromLine <= 10_101 && $0.toLine >= 10_101 })
        let aKey = "note:\(alpha.id)"
        let bKey = "note:\(beta.id)"
        let cKey = "note:\(gamma.id)"
        let dKey = "archive:\(archive.id)"
        for item in entries {
            let vector: [Double]
            if item.entityID == aKey || item.entityID == bKey { vector = [1, 0, 0] }
            else if item.entityID == cKey { vector = [0, 1, 0] }
            else if item.entityID == dKey && item.text.contains("API timeout") { vector = [0.96, 0.28, 0] }
            else { vector = [0, 0, 1] }
            try db.saveMemoryVector(item: item, model: "bge-m3", vector: vector)
        }
        let stored = try db.memoryVectors()
        assert(stored.count == entries.count)
        let related = MemoryEngine.related(entityID: aKey, vectors: stored, threshold: 0.70)
        assert(related.first(where: { $0.id == bKey }) != nil, "Similar note should be found")
        assert(related.first(where: { $0.id == cKey }) == nil, "Unrelated note should not be shown")
        assert(related.contains(where: { $0.id == dKey }), "Archived chunk also appears")
        try db.createCategory(name: "Engineering", kind: "book")
        let types = try db.categories(kind: "type")
        let recommend = MemoryEngine.classifications(neighbors: related, notes: try db.notes(),
            categories: types, kind: "type", excluding: "type-meeting")
        assert(recommend.first?.id == "type-work")
        let link = MemoryLink(aKey, bKey)
        try db.addMemoryLink(link)
        try db.addMemoryLink(link)
        let linkCount = try db.confirmedLinks().count
        assert(linkCount == 1, "Link must be idempotent")
        let graph = MemoryEngine.graph(notes: try db.notes(), archives: try db.archives(),
            vectors: stored, confirmed: try db.confirmedLinks(), threshold: 0.72)
        assert(graph.nodes.count == 4)
        assert(graph.edges.contains(where: { $0.id == link.id && $0.confirmed }))
        let backup = try db.exportBrowserCompatibleJSON()
        let json = try JSONSerialization.jsonObject(with: backup) as! [String: Any]
        assert((json["memoryLinks"] as? [[String: String]])?.count == 1)
        let importResult = try db.importBrowserBackup(backup)
        assert(importResult.notes == 0)
        let restoredLinks = try db.confirmedLinks()
        assert(restoredLinks.count == 1)
        try db.removeMemoryLink(link)
        let linksAfterRemoval = try db.confirmedLinks()
        assert(linksAfterRemoval.isEmpty)
        _ = try db.importBrowserBackup(backup)
        let linksFromBackup = try db.confirmedLinks()
        assert(linksFromBackup.count == 1, "JSON restore should include confirmed link")
        let changed = MemoryIndexItem(id: "note:\(alpha.id):0", entityID: aKey,
            kind: "note", title: alpha.visibleTitle, text: "Changed note fingerprint")
        try db.saveMemoryVector(item: changed, model: "bge-m3", vector: [1, 0, 0])
        let savedSignatures = try db.memorySignatures()
        assert(savedSignatures[changed.id] == changed.signature)
        try db.removeMemoryIndexItem(changed.id)
        let afterDeletingIndex = try db.memorySignatures()
        assert(afterDeletingIndex[changed.id] == nil)
        print("PASS memory smoke: embedding persistence, 11k lines, related records, category suggestions, clusters, confirmed links + JSON restore")
    }
}
