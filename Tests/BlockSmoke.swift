import Foundation

@main struct BlockSmoke {
    static func main() {
        let sample = "| 제목 | 설명 |\n| --- | --- |\n| 항목 | 한글과 이모지 🧪 |"
        let parsed = WorkOSTable.parse(sample)
        precondition(parsed?.count == 2 && parsed?[1][1] == "한글과 이모지 🧪")
        precondition(WorkOSTable.markdown(parsed!) == sample)
        let slash = "| 제목 | 코드 |\n| --- | --- |\n| 테스트 | X \\| Y |"
        precondition(WorkOSTable.parse(slash)?[1][1] == "X | Y")
        precondition(WorkOSTable.parse("| x | y |\n| false | -- |") == nil)
        let chart = "flowchart TD\n  A[시작] --> B{확인}\n  B -->|예| C[완료]\n  B -->|아니요| D[다시 검토]"
        let svg = MermaidFlowchart.svg(chart)
        precondition(svg?.contains("<svg") == true)
        precondition(svg?.contains("다시 검토") == true)
        precondition(MermaidFlowchart.svg("sequenceDiagram\nA->>B: hello") == nil)
        let formula = WorkBlock.make(.equation)
        let table = WorkBlock(id: "sample", kind: .table, source: sample)
        let encoded = WorkBlock.encode([table, formula])
        precondition(WorkBlock.read(encoded).count == 2)
        let basic: [String:Any] = [
            "id": "123", "title": "노트 & 메모", "noteDate": "2026-10-16", "status": "진행 중",
            "body": "<html><head><style>body{color:red}</style></head><body><h2>본문</h2><p>안녕</p></body></html>",
            "workosBlocks": encoded
        ]
        let note = WorkNote.from(basic)
        let markdown = NoteDocuments.markdown(note: note)
        precondition(markdown.contains("$$\nE = mc^2\n$$"))
        precondition(markdown.contains(sample))
        let html = NoteDocuments.html(note: note)
        precondition(html.contains("노트 &amp; 메모"))
        precondition(html.contains("<table"))
        precondition(!html.contains("<html><head><style>body{color:red}"))
        precondition(html.contains("data-tex="))
        precondition(NoteDocuments.safeHTML("<p>A</p><script>alert(1)</script>") == "<p>A</p>")
        print("PASS: table roundtrip, escaped pipes, Mermaid SVG subset, Math/HTML/Markdown blocks, sanitization")
    }
}
