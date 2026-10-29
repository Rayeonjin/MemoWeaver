import Foundation

@main struct MarkdownContextV0943Smoke {
    static func check(_ note: String, anchor: String, expected: MarkdownEditingContext,
                      label: String) {
        let string = note as NSString
        let range = string.range(of: anchor)
        precondition(range.location != NSNotFound, "Missing test marker: \(label)")
        let actual = MarkdownContextCore.context(in: note, utf16Offset: range.location + 1)
        precondition(actual == expected, "\(label): expected \(expected), got \(actual)")
    }
    static func main() {
        check("앞\n$$\n\\frac{x}{y}\n$$\n뒤", anchor: "frac", expected: .math,
              label: "LaTeX math block")
        check("\\[\n\\sum_{i=1}^n\n\\]\n뒤", anchor: "sum", expected: .math,
              label: "bracketed LaTeX")
        check("```latex\n\\frac{x}{y}\n```", anchor: "frac", expected: .math,
              label: "fenced LaTeX")
        check("```math\n\\frac{x}{y}\n```", anchor: "frac", expected: .math,
              label: "fenced math")
        check("```mermaid\nflowchart TD\nA-->B\n```", anchor: "flowchart", expected: .mermaid,
              label: "Mermaid flowchart")
        check("```mermaid\nxychart-beta\nbar [1, 2]\n```", anchor: "bar", expected: .mermaidXY,
              label: "Mermaid XY chart")
        check("```mermaid\nsequenceDiagram\nA->>B: hello\n```", anchor: "hello", expected: .mermaidSequence,
              label: "Mermaid sequence")
        check("```markmap\n# 주제\n- 하위 항목\n```", anchor: "항목", expected: .markmap,
              label: "Markmap fenced block")
        check("$$\nx\n$$\n일반 문장", anchor: "문장", expected: .normal,
              label: "return to normal after math block")
        check("```mermaid\nflowchart TD\nA-->B\n```\n일반 문장", anchor: "문장",
              expected: .normal, label: "return to normal after Mermaid")
        let math = MarkdownAssistGroup.allCases.filter { $0.context == .math }
        precondition(math.count == 4)
        precondition(MarkdownAssistSnippet.allCases.filter { $0.context == .math }.count >= 20)
        precondition(MarkdownAssistSnippet.allCases.filter { $0.context == .markmap }.count >= 3)
        print("PASS context: LaTeX (3 delimiters), Mermaid flow/XY/sequence, Markmap, exit, 4 grouped math menus")
    }
}
