import Foundation

@main
struct MultiNotebookSmoke {
    static func check(_ condition: @autoclosure () -> Bool, _ label: String) {
        guard condition() else {
            fputs("FAIL \(label)\n", stderr)
            exit(1)
        }
        print("PASS \(label)")
    }

    static func main() {
        let legacy: [String: Any] = ["bookId": "A"]
        check(NotebookMembershipCore.from(legacy) == ["A"], "legacy primary notebook")
        let explicit: [String: Any] = ["bookId": "A", "notebookIds": ["B", "A", "B", "C"]]
        check(NotebookMembershipCore.from(explicit) == ["A", "B", "C"], "ordered deduplication")
        check(NotebookMembershipCore.toggled("B", in: ["A", "B"]) == ["A"], "remove one membership")
        check(NotebookMembershipCore.toggled("C", in: ["A", "B"]) == ["A", "B", "C"], "add membership without copies")
        check(NotebookMembershipCore.normalized(primary: "", ids: ["A", "A"]) == ["A"], "empty legacy primary")
        check(NotebookMembershipCore.normalized(primary: "", ids: []) == [], "unassigned notebook")
        let raw = ["bookId": "A", "notebookIds": ["A", "B"]] as [String: Any]
        check(NotebookMembershipCore.from(raw).contains("B"), "secondary notebook matched")
        print("PASS notebook membership core")
    }
}
