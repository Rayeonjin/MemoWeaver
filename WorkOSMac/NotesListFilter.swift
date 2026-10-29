import Foundation

// The four list views are filters over one SQLite notes table, never separate stores.
enum NotesListScope: String, CaseIterable, Identifiable {
    case all, today, recent, pinned
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "전체"
        case .today: return "오늘"
        case .recent: return "최근"
        case .pinned: return "고정"
        }
    }
}

enum NotesListFilter {
    static func matches(_ note: WorkNote, scope: NotesListScope,
                        bookID: String = "", typeID: String = "",
                        today: String = WorkOSDate.day(), recentStart: String? = nil) -> Bool {
        guard note.deletedAt.isEmpty else { return false }
        if !bookID.isEmpty && !note.notebookIDs.contains(bookID) { return false }
        if !typeID.isEmpty && note.typeID != typeID { return false }
        switch scope {
        case .all: return true
        case .pinned: return note.pinned
        case .today:
            return note.noteDate == today || note.localUpdatedDay == today ||
                note.progress.contains { WorkOSJSON.string($0, "noteDate") == today }
        case .recent:
            // Compare dates in the same local calendar as the filter boundaries.
            let cutoff = recentStart ?? WorkOSDate.day(Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date())
            return note.localUpdatedDay >= cutoff
        }
    }
}
