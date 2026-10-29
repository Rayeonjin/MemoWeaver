import Foundation

/// Immutable, read-only snapshot. The reference view never receives an editable
/// binding, so opening a past memory cannot replace the active editor's note.
struct MemoryReferenceSnapshot: Identifiable {
    let id: String
    let title: String
    let caption: String
    let body: String
    let editableEntityID: String
}

enum MemoryReferenceCore {
    static func lineExcerpt(_ source: String, from: Int, to: Int, padding: Int = 8) -> String {
        guard from > 0, to >= from else { return source }
        let lines = source.components(separatedBy: "\n")
        guard !lines.isEmpty else { return source }
        let first = max(0, from - 1 - max(0, padding))
        let last = min(lines.count, to + max(0, padding))
        guard first < last else { return source }
        return (first..<last).map { index in
            String(index + 1) + "  " + lines[index]
        }.joined(separator: "\n")
    }
}
