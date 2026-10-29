import Foundation

// A daily inbox is a regular WorkNote, not a new silo. It is safe in SQLite,
// available to search/AI/backups, and can later be opened in the full editor.
enum WorkOSQuickCapture {
    static func title(for day: String) -> String { "빠른 기록 · " + day }

    // New, individually addressable quick notes use ordinary note storage and editor.
    // The old daily scratchpad is identified by quickCaptureDay and stays untouched.
    static func isCapture(_ note: WorkNote) -> Bool {
        let raw = WorkOSJSON.dictionary(note.rawJSON)
        return (raw["quickCaptureMode"] as? String) == "multi" ||
            (raw["quickCaptureDay"] as? String) != nil
    }

    static func isNewCapture(_ note: WorkNote) -> Bool {
        WorkOSJSON.string(WorkOSJSON.dictionary(note.rawJSON), "quickCaptureMode") == "multi"
    }

    static func isEmptyNewCapture(_ note: WorkNote, day: String) -> Bool {
        isNewCapture(note) && note.noteDate == day &&
            note.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            note.plainBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            note.workosBlocks.isEmpty && note.progress.isEmpty
    }

    static func inferredTitle(_ text: String, limit: Int = 56) -> String {
        guard let line = text.split(whereSeparator: \.isNewline)
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) else { return "새 빠른 기록" }
        return line.count > limit ? String(line.prefix(limit)) + "…" : line
    }


    static func isDailyNote(_ note: WorkNote, day: String) -> Bool {
        note.deletedAt.isEmpty && !isNewCapture(note) &&
            WorkOSJSON.string(WorkOSJSON.dictionary(note.rawJSON), "quickCaptureDay") == day
    }

    static func plainText(_ note: WorkNote) -> String {
        let raw = WorkOSJSON.dictionary(note.rawJSON)
        // A migrated capture uses its current Markdown body, not the old
        // compatibility-only quickCaptureText snapshot.
        if note.isMarkdown { return note.bodyHTML }
        return (raw["quickCaptureText"] as? String) ?? HTMLText.plain(note.bodyHTML)
    }

    static func html(_ text: String) -> String {
        // Escape BEFORE adding line breaks. The literal text is preserved in quickCaptureText.
        let escaped = text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "\n", with: "<br>")
        return "<p>" + escaped + "</p>"
    }

    // Never silently overwrite HTML formatting added later in the full editor.
    static func isPlainCapture(_ note: WorkNote) -> Bool {
        let raw = WorkOSJSON.dictionary(note.rawJSON)
        guard let saved = raw["quickCaptureText"] as? String else { return false }
        return note.bodyHTML == html(saved)
    }
}
