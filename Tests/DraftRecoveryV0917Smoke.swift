import Foundation
@main
struct DraftRecoveryV0917Smoke {
    static func main() async throws {
        let id = UUID().uuidString
        let snap = MemoWeaverRecoveryDraft(noteID: id, storageEpoch: "test", baseRevision: "t0",
            capturedAt: "t1", title: "업무", body: "입력 중 저장되지 않은 메모\n두 번째 줄",
            typeID: "type-note", bookID: "", noteDay: "2026-10-26", status: "진행 중",
            sourceURL: "", pinned: false)
        try await MemoWeaverDraftRecoveryStore.shared.write(snap)
        let found = await MemoWeaverDraftRecoveryStore.shared.read(noteID: id)
        guard found?.body == snap.body, found?.baseRevision == "t0" else {
            fatalError("draft recovery persisted content changed")
        }
        // Failure path must work without awaiting a background actor task.
        let emergency = MemoWeaverRecoveryDraft(noteID: id, storageEpoch: "test", baseRevision: "t0",
            capturedAt: "t3", title: "업무", body: "긴급 저장해야 할 마지막 문장",
            typeID: "type-note", bookID: "", noteDay: "2026-10-26", status: "진행 중",
            sourceURL: "", pinned: false)
        try MemoWeaverDraftRecoveryStore.emergencyWrite(emergency)
        try await MemoWeaverDraftRecoveryStore.shared.write(snap)
        let protected = await MemoWeaverDraftRecoveryStore.shared.read(noteID: id)
        guard protected?.body == emergency.body else {
            fatalError("older asynchronous snapshot overwrote urgent recovery")
        }
        await MemoWeaverDraftRecoveryStore.shared.remove(noteID: id)
        guard await MemoWeaverDraftRecoveryStore.shared.read(noteID: id) == nil else {
            fatalError("saved recovery journal was not removed")
        }
        print("PASS QA v0.9.17 recovery journal, urgent failure write, stale overwrite protection and removal")
    }
}
