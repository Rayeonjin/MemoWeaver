import Foundation

// Read-only reference panel. User-confirmed links and *validated* AI relations
// are distinct; a high embedding similarity is never a confirmed relationship.
struct ReferencePanelEntry: Identifiable, Hashable {
    let id: String
    let source: String                 // manual | ai | search
    let label: String
    let detail: String
    let fromLine: Int
    let toLine: Int
}

struct ManualRelationChoice: Identifiable, Hashable {
    let code: String
    let label: String
    var id: String { code }
}

enum ReferencePanelCore {
    static let manualKinds: [ManualRelationChoice] = [
        ManualRelationChoice(code: "related", label: "관련 있음"),
        ManualRelationChoice(code: "follow_up", label: "후속 기록"),
        ManualRelationChoice(code: "resolves", label: "문제·해결"),
        ManualRelationChoice(code: "supports", label: "근거·판단"),
        ManualRelationChoice(code: "contrasts", label: "상반된 판단")
    ]

    static func manualLabel(_ kind: String) -> String {
        manualKinds.first(where: { $0.code == kind })?.label ?? "관련 있음"
    }

    static func sanitizeKind(_ kind: String) -> String {
        MemoryLink.sanitizeKind(kind)
    }

    static func related(centers: [String], confirmed: [MemoryLink],
                        inferred: [MemoryInferredRelation], valid: Set<String>) -> [ReferencePanelEntry] {
        let sources = Set(centers)
        var result: [ReferencePanelEntry] = []
        var seen = Set<String>()
        for link in confirmed {
            let other = sources.contains(link.first) ? link.second :
                (sources.contains(link.second) ? link.first : "")
            guard valid.contains(other), !sources.contains(other), !seen.contains(other) else { continue }
            seen.insert(other)
            result.append(ReferencePanelEntry(id: other, source: "manual",
                label: "직접 연결 · " + manualLabel(link.relationKind),
                detail: link.memo, fromLine: 0, toLine: 0))
        }
        for relation in inferred where relation.hasRelationship {
            let other = sources.contains(relation.fromID) ? relation.toID :
                (sources.contains(relation.toID) ? relation.fromID : "")
            guard valid.contains(other), !sources.contains(other), !seen.contains(other) else { continue }
            seen.insert(other)
            result.append(ReferencePanelEntry(id: other, source: "ai",
                label: "AI 추론 · " + relation.typeLabel,
                detail: relation.summary, fromLine: 0, toLine: 0))
        }
        return result
    }

    // Bounded rendering, even for imported TXT files with 10,000+ lines.
    // Copying or opening the independent reader still uses the full original.
    static func limitedText(_ text: String, maxCharacters: Int) -> (text: String, more: Bool) {
        let limit = max(1, maxCharacters)
        guard text.count > limit else { return (text, false) }
        return (String(text.prefix(limit)), true)
    }

    static func entityID(for result: MemorySource) -> String {
        if result.id.hasPrefix("virtual:") { return result.id }
        if result.kind == "archive" { return "archive:" + result.sourceID }
        return "note:" + result.sourceID
    }
}
