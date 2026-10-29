import Foundation

// Sidebar is an ego-network, not a second graph engine. Pure selection rules
// ensure that opening notes never mutates saved source text or vectors.
struct SideMemoryRange: Equatable {
    let entityID: String
    let sourceNoteID: String
    let firstLine: Int
    let lastLine: Int
}

enum SideMemoryRules {
    static func focus(noteID: String, caretLine: Int, ranges: [SideMemoryRange]) -> String {
        guard caretLine > 0 else { return "note:" + noteID }
        let candidate = ranges.first {
            $0.sourceNoteID == noteID && $0.firstLine <= caretLine && caretLine <= $0.lastLine
        }
        return candidate?.entityID ?? "note:" + noteID
    }

    // Manually confirmed relationships take precedence, then the strongest
    // semantic results. Invalid/deleted records and duplicate IDs are ignored.
    static func neighborIDs(center: String, confirmed: [String], semantic: [String],
                            valid: Set<String>, limit: Int = 5) -> [String] {
        guard limit > 0 else { return [] }
        var seen: Set<String> = [center]
        var result: [String] = []
        for id in confirmed + semantic {
            guard valid.contains(id), seen.insert(id).inserted else { continue }
            result.append(id)
            if result.count == limit { break }
        }
        return result
    }
}
