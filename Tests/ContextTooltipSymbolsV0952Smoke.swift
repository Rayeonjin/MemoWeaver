import Foundation

@main
struct ContextTooltipSymbolsV0952Smoke {
    static func main() {
        // Verify the same source model used by toolbar and slash palette.
        let snippets = MarkdownAssistSnippet.allCases
        let rawIDs = snippets.map(\.rawValue)
        precondition(Set(rawIDs).count == rawIDs.count, "duplicate symbol command")
        let math = snippets.filter { $0.context == .math }
        let symbol = math.filter { $0.group == .mathSymbols }
        precondition(snippets.count >= 160, "full command catalog must be retained")
        precondition(symbol.count >= 96, "expanded Greek/maths symbols disappeared")
        for item in snippets {
            precondition(!item.title.isEmpty, "blank symbol title: \(item)")
            precondition(!item.source.isEmpty, "blank insertion template: \(item)")
        }
        for sample in [MarkdownAssistSnippet.upperSigma, .naturalNumbers, .nabla,
                       .varphi, .doubleLeftArrow, .contourIntegral, .logicalNot] {
            precondition(sample.context == .math)
            precondition(sample.group == .mathSymbols)
        }
        let text = "오늘 메모\n$$\nE = mc^2\n$$\n다음 메모"
        let location = (text as NSString).range(of: "E = mc^2").location + 1
        precondition(MarkdownContextCore.context(in: text, utf16Offset: location) == .math,
                     "freshly inserted math block must show contextual toolbar")
        let outside = (text as NSString).range(of: "다음 메모").location + 1
        precondition(MarkdownContextCore.context(in: text, utf16Offset: outside) == .normal,
                     "math toolbar must disappear outside math block")
        let diagram = "문서\n```mermaid\nflowchart TD\nA[시작] --> B[끝]\n```\n"
        let dLoc = (diagram as NSString).range(of: "A[시작]").location + 1
        precondition(MarkdownContextCore.context(in: diagram, utf16Offset: dLoc) == .mermaid,
                     "Mermaid block must show flowchart tools")
        print("PASS 0.9.52: \(snippets.count) catalog commands, \(symbol.count) math symbols, context insertion")
    }
}
