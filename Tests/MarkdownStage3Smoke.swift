import Foundation

@main
struct MarkdownStage3Smoke {
    static func main() {
        let math = MarkdownAssistSnippet.allCases.filter { $0.context == .math }
        let flow = MarkdownAssistSnippet.allCases.filter { $0.context == .mermaid }
        assert(math.count >= 25, "Math palette should cover symbols, operators, structures")
        assert(flow.count >= 8, "Flow palette should cover shapes, links, patterns")
        assert(Set(math.map(\.group)).count == 4)
        assert(Set(flow.map(\.group)).count == 3)
        assert(MarkdownAssistGroup.allCases.allSatisfy { group in
            MarkdownAssistSnippet.allCases.contains(where: { $0.group == group })
        })
        for snippet in MarkdownAssistSnippet.allCases {
            let length = (snippet.source as NSString).length
            assert(length > 0 && snippet.caretBack >= 0 && snippet.caretBack <= length,
                   "Illegal caret position in \(snippet.rawValue)")
            assert(!snippet.source.contains("```"), "Palettes never nest a fenced code block")
            assert(!snippet.help.isEmpty)
            if snippet.wrapsSelection {
                let prepared = MarkdownAssistInsertionCore.prepare(
                    source: snippet.source, caretBack: snippet.caretBack,
                    selectedText: "한글 + x", wrapsSelection: true)
                assert(prepared.source.contains("한글 + x"))
                let p = (prepared.source as NSString).length - prepared.caretBack
                assert(p >= ("한글 + x" as NSString).length)
            }
        }
        let frac = MarkdownAssistSnippet.fraction
        let fraction = MarkdownAssistInsertionCore.prepare(source: frac.source,
            caretBack: frac.caretBack, selectedText: "x+y", wrapsSelection: frac.wrapsSelection)
        assert(fraction.source == #"\frac{x+y}{b}"#)
        assert((fraction.source as NSString).length - fraction.caretBack == ( #"\frac{x+y"# as NSString).length)
        let sqrt = MarkdownAssistSnippet.squareRoot
        assert(MarkdownAssistInsertionCore.prepare(source: sqrt.source, caretBack: sqrt.caretBack,
            selectedText: "✅한글", wrapsSelection: true).source == #"\sqrt{✅한글}"#)
        let normal = MarkdownAssistInsertionCore.prepare(source: frac.source,
            caretBack: frac.caretBack, selectedText: "", wrapsSelection: true)
        assert(normal.source == frac.source && normal.caretBack == frac.caretBack)
        // Mermaid commands use only the subset this offline renderer actually supports.
        for snippet in flow where snippet != .comment {
            guard let svg = MermaidFlowchart.svg("flowchart TD\n" + snippet.source) else {
                fatalError("Flow command renders invalid offline Mermaid: \(snippet.rawValue)")
            }
            assert(svg.contains("<svg"))
        }
        assert(MermaidFlowchart.svg("flowchart TD\n" + MarkdownAssistSnippet.comment.source + "\nA[시작]") != nil)
        assert(MarkdownAssistSnippet.branch.beginsOnNewLine)
        assert(MarkdownAssistSnippet.connection.beginsOnNewLine == false)
        // True Markdown editing remains non-destructive across new helper actions.
        let raw = "$$\nE = mc^2\n$$\n\n\n- 오늘은\n  - 재미있니?\n"
        _ = MarkdownPreviewCore.render(raw)
        assert(MarkdownContextCore.context(in: raw, utf16Offset: 5) == .math)
        assert(raw == "$$\nE = mc^2\n$$\n\n\n- 오늘은\n  - 재미있니?\n")
        print("PASS stage 3: grouped 1-click LaTeX/Mermaid palettes, UTF-16 caret/wrap, offline flowchart syntax and immutable Markdown")
    }
}
