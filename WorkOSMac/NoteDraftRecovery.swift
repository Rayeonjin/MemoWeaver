import Foundation

// A second, intentionally independent local safety net for edits that have
// not reached the SQLite autosave interval. Never modifies a note on startup:
// the user explicitly chooses to restore or discard an eligible draft.
struct MemoWeaverRecoveryDraft: Codable {
    let noteID: String
    let storageEpoch: String
    let baseRevision: String
    let capturedAt: String
    let title: String
    let body: String
    let typeID: String
    let bookID: String
    // Optional for backwards compatibility with recovery drafts created before multi-notebook support.
    var notebookIDs: [String]? = nil
    let noteDay: String
    let status: String
    let sourceURL: String
    let pinned: Bool
}

actor MemoWeaverDraftRecoveryStore {
    static let shared = MemoWeaverDraftRecoveryStore()

    // Synchronous last-resort write for an SQLite autosave failure or window
    // teardown. The app may terminate before another detached Task can start.
    // A newer journal wins; do not replace it with an older queued write.
    nonisolated static func emergencyWrite(_ draft: MemoWeaverRecoveryDraft) throws {
        guard let url = fileLocation(draft.noteID) else { return }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        if let previousData = try? Data(contentsOf: url),
           let previous = try? JSONDecoder().decode(MemoWeaverRecoveryDraft.self, from: previousData),
           previous.storageEpoch == draft.storageEpoch,
           previous.capturedAt > draft.capturedAt { return }
        let data = try JSONEncoder().encode(draft)
        try data.write(to: url, options: .atomic)
    }

    nonisolated private static func fileLocation(_ id: String) -> URL? {
        // A note ID is never permitted to escape the recovery directory.
        guard !id.isEmpty,
              id.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else {
            return nil
        }
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WorkOS", isDirectory: true)
            .appendingPathComponent("RecoveryDrafts", isDirectory: true)
        return directory.appendingPathComponent(id + ".json", isDirectory: false)
    }

    private func fileURL(_ id: String) -> URL? { Self.fileLocation(id) }

    func write(_ draft: MemoWeaverRecoveryDraft) throws {
        try Self.emergencyWrite(draft)
    }

    func read(noteID: String) -> MemoWeaverRecoveryDraft? {
        guard let url = fileURL(noteID),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(MemoWeaverRecoveryDraft.self, from: data)
    }

    func remove(noteID: String) {
        guard let url = fileURL(noteID) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
