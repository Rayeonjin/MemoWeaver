import Foundation

@main
struct MultiNotebookRecoveryFixSmoke {
    static func main() throws {
        let old = """
        {"noteID":"old","storageEpoch":"x","baseRevision":"r","capturedAt":"2026-10-27","title":"old","body":"body","typeID":"memo","bookID":"one","noteDay":"2026-10-27","status":"","sourceURL":"","pinned":false}
        """
        let decoder = JSONDecoder()
        let legacy = try decoder.decode(MemoWeaverRecoveryDraft.self, from: Data(old.utf8))
        guard legacy.notebookIDs == nil, legacy.bookID == "one" else { fatalError("legacy recovery failed") }
        var updated = legacy
        updated.notebookIDs = ["one", "two"]
        let encoded = try JSONEncoder().encode(updated)
        let restored = try decoder.decode(MemoWeaverRecoveryDraft.self, from: encoded)
        guard restored.notebookIDs == ["one", "two"] else { fatalError("multi-notebook recovery failed") }
        print("PASS: legacy and multiple notebook recovery drafts")
    }
}
