import Foundation

@main struct MarkdownAssistCatalogV0945Smoke {
    static func main() {
        let entries = MarkdownAssistSnippet.allCases
        precondition(entries.count >= 75, "Expanded context catalog missing entries")
        precondition(Set(entries.map(\.rawValue)).count == entries.count)
        for tool in entries {
            precondition(!tool.title.isEmpty && !tool.source.isEmpty, "Empty editing tool")
            precondition(tool.caretBack >= 0 && tool.caretBack <= (tool.source as NSString).length,
                         "Invalid caret offset for \(tool.rawValue)")
            precondition(tool.context == tool.group.context, "Unexpected block context")
        }
        for group in MarkdownAssistGroup.allCases {
            precondition(entries.filter { $0.group == group }.count >= 2,
                         "Empty or incomplete dropdown group: \(group.title)")
        }
        precondition(MarkdownAssistSnippet.binomial.source == "\\binom{n}{k}")
        precondition(MarkdownAssistSnippet.matrix3x3.source.contains("bmatrix"))
        precondition(MarkdownAssistSnippet.subgraphBlock.source.contains("\nend"))
        precondition(MarkdownAssistSnippet.sequenceAlternative.source.contains("else"))
        precondition(MarkdownAssistSnippet.sequenceLoop.source.contains("\nend"))
        precondition(MarkdownAssistSnippet.markmapBold.source.contains("**"))
        precondition(MarkdownAssistSnippet.ganttExcludes.context == .mermaidGantt)
        precondition(MarkdownAssistSnippet.xyTitle.context == .mermaidXY)
        precondition(MarkdownAssistSnippet.pieAnotherSlice.context == .mermaidPie)
        let prepared = MarkdownAssistInsertionCore.prepare(
            source: MarkdownAssistSnippet.overline.source,
            caretBack: MarkdownAssistSnippet.overline.caretBack,
            selectedText: "z", wrapsSelection: MarkdownAssistSnippet.overline.wrapsSelection)
        precondition(prepared.source.contains("{z}"))
        print("PASS v0.9.45 context catalog: \(entries.count) tools, group membership, caret positioning and rich snippets")
    }
}
