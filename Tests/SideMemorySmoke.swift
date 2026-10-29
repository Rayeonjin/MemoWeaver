import Foundation

@main
struct SideMemorySmoke {
    static func main() {
        let ranges = [
            SideMemoryRange(entityID: "virtual:a", sourceNoteID: "n1", firstLine: 1, lastLine: 100),
            SideMemoryRange(entityID: "virtual:b", sourceNoteID: "n1", firstLine: 101, lastLine: 200),
            SideMemoryRange(entityID: "virtual:c", sourceNoteID: "n2", firstLine: 1, lastLine: 100)
        ]
        assert(SideMemoryRules.focus(noteID: "n1", caretLine: 0, ranges: ranges) == "note:n1")
        assert(SideMemoryRules.focus(noteID: "n1", caretLine: 1, ranges: ranges) == "virtual:a")
        assert(SideMemoryRules.focus(noteID: "n1", caretLine: 100, ranges: ranges) == "virtual:a")
        assert(SideMemoryRules.focus(noteID: "n1", caretLine: 101, ranges: ranges) == "virtual:b")
        assert(SideMemoryRules.focus(noteID: "n1", caretLine: 201, ranges: ranges) == "note:n1")
        assert(SideMemoryRules.focus(noteID: "n3", caretLine: 2, ranges: ranges) == "note:n3")
        let IDs = SideMemoryRules.neighborIDs(center: "note:main",
            confirmed: ["note:main", "virtual:a", "note:gone", "virtual:a"],
            semantic: ["virtual:a", "note:x", "note:y", "note:z", "note:q", "note:r"],
            valid: Set(["note:main", "virtual:a", "note:x", "note:y", "note:z", "note:q", "note:r"]))
        assert(IDs == ["virtual:a", "note:x", "note:y", "note:z", "note:q"])
        assert(SideMemoryRules.neighborIDs(center: "note:main", confirmed: [],
            semantic: ["note:x"], valid: ["note:x"], limit: 0).isEmpty)
        print("PASS side memory focus: virtual range boundary, fallback, confirmed priority, cap, invalid IDs")
    }
}
