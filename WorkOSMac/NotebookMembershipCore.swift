import Foundation

// A memo is stored once. Membership is a collection of notebook IDs, not copies
// of the memo. The first ID is the backward-compatible bookId (primary notebook).
enum NotebookMembershipCore {
    static func normalized(primary: String, ids: [String]) -> [String] {
        var unique: [String] = []
        var seen = Set<String>()
        for id in ([primary] + ids).map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) {
            guard !id.isEmpty, seen.insert(id).inserted else { continue }
            unique.append(id)
        }
        return unique
    }

    static func from(_ raw: [String: Any]) -> [String] {
        normalized(primary: raw["bookId"] as? String ?? "", ids: raw["notebookIds"] as? [String] ?? [])
    }

    static func toggled(_ id: String, in current: [String]) -> [String] {
        guard !id.isEmpty else { return current }
        if current.contains(id) { return current.filter { $0 != id } }
        return current + [id]
    }
}
