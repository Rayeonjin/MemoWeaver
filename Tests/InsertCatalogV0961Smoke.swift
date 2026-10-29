import Foundation

@main
struct InsertCatalogV0961Smoke {
    static func check(_ valid: @autoclosure () -> Bool, _ description: String) {
        precondition(valid(), description)
    }

    static func context(of request: MarkdownInsertRequest) -> MarkdownEditingContext {
        let source = request.source as NSString
        let caret = source.length - request.caretBack
        check(caret >= 0 && caret <= source.length, "caret outside template")
        return MarkdownContextCore.context(in: request.source, utf16Offset: caret)
    }

    static func main() {
        let expected: [(MermaidDiagramTemplates.Kind, MarkdownEditingContext)] = [
            (.gantt, .mermaidGantt), (.timeline, .mermaidTimeline),
            (.sequence, .mermaidSequence), (.classDiagram, .mermaidClass),
            (.stateDiagram, .mermaidState), (.erDiagram, .mermaidER),
            (.gitGraph, .mermaidGit), (.journey, .mermaidJourney)
        ]
        for (kind, dialect) in expected {
            let request = MermaidDiagramTemplates.insertion(for: kind)
            check(context(of: request) == dialect, "Mermaid dialect caret: \(kind.rawValue)")
            let preview = MarkdownPreviewCore.render(request.source)
            check(preview.html.contains("data-workos-diagram"), "official Mermaid wrapper: \(kind.rawValue)")
            check(MemoWeaverDiagramExtraTools.items(for: dialect).count >= 2,
                  "matching context tools \(kind.rawValue)")
        }
        let quadrant = MermaidChartTemplates.insertion(for: .quadrant)
        check(context(of: quadrant) == .mermaidQuadrant, "quadrant context")
        check(MemoWeaverDiagramExtraTools.items(for: .mermaidQuadrant).count >= 2,
              "quadrant assist tools")

        let code = MarkdownTemplates.insertion(for: .code)
        check(context(of: code) == .code, "plain code caret context")
        check(code.source.hasPrefix("```text\n"), "portable code fenced template")
        for language in MemoWeaverCodeTemplates.allCases {
            let request = language.insertion()
            check(context(of: request) == .code, "language caret \(language.rawValue)")
            check(request.source.hasPrefix("```\(language.language)\n"), "language tag")
            let html = MarkdownPreviewCore.render(request.source).html
            check(html.contains("<pre data-language='\(language.language)'>"), "language label")
            check(html.contains("코드를 입력하세요"), "code input placeholder")
        }
        check(MemoWeaverCodeTemplates.allCases.count >= 20, "code languages")
        check(MemoWeaverMarkdownExtras.Group.allCases.flatMap(MemoWeaverMarkdownExtras.items).count >= 15,
              "additional Markdown templates")
        let inlineCode = MemoWeaverMarkdownExtras.items(.text).first { $0.id == "inline-code" }!
        let wrapped = MarkdownAssistInsertionCore.prepare(source: inlineCode.source,
            caretBack: inlineCode.insertion().caretBack, selectedText: "여기",
            wrapsSelection: inlineCode.wrapsSelection)
        check(wrapped.source == "`여기`", "selection must be wrapped without leftover placeholder")
        let highlight = MemoWeaverMarkdownExtras.items(.text).first { $0.id == "highlight" }!
        check(MarkdownPreviewCore.render(highlight.source).html.contains("<mark>x</mark>"),
              "highlight must render, not remain inert markup")
        let folded = MemoWeaverMarkdownExtras.items(.blocks).first { $0.id == "callout-fold" }!
        let foldHTML = MarkdownPreviewCore.render(folded.source).html
        check(foldHTML.contains("<details class='callout'>"), "foldable callout")
        check(foldHTML.contains("<summary>NOTE · 접기 제목</summary>"), "foldable callout title")
        check(!foldHTML.contains("<script"), "no executable HTML from source")
        let multi = MemoWeaverMarkdownExtras.items(.math).first { $0.id == "math-gathered" }!
        check(multi.source.contains(" \\\\\n"), "math line break must be two slashes plus newline")
        check(context(of: multi.insertion()) == .math, "multiline math caret context")
        let mathTool = MemoWeaverDiagramExtraTools.items(for: .math).first { $0.id == "math-boxed" }!
        check(mathTool.source.hasPrefix("\\boxed"), "KaTeX source one escape slash")
        check(MemoWeaverDiagramExtraTools.items(for: .markmap).count >= 4, "markmap tools")
        check(!MemoWeaverDiagramExtraTools.items(for: .mermaid).isEmpty, "flowchart tools")
        let additionalSlash = SlashCommandCore.matches("사분면")
        check(additionalSlash.contains(where: { $0.id == "chart-quadrant" }),
              "new toolbar templates also discoverable with slash")
        print("PASS v0.9.61: 8 Mermaid dialects + quadrant, 21 code languages, extended Markdown")
        print("PASS v0.9.61: insertion caret, legacy wrapper, code label, math newlines, highlight, folded callout")
    }
}
