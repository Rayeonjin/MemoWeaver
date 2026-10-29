import Foundation

@main
struct MarkdownStage2Smoke {
    static func main() {
        // Preview-only source anchors must not change the nested-list HTML
        // structure tested since v0.9.2.
        func withoutAnchors(_ html: String) -> String {
            html.replacingOccurrences(of: #"<div class='md-block' data-md-line='[0-9]+'>"#,
                                       with: "", options: .regularExpression)
                .replacingOccurrences(of: #"<li data-md-line='[0-9]+'>"#,
                                      with: "<li>", options: .regularExpression)
                .replacingOccurrences(of: "</div>", with: "")
        }
        let source = "- 상위 업무\n  - 하위 업무\n    - 상세 업무\n  - 두 번째 하위\n- 다음 상위"
        let syncedHTML = MarkdownPreviewCore.render(source).html
        assert(syncedHTML.contains("<li data-md-line='3'>상세 업무"), syncedHTML)
        let html = withoutAnchors(syncedHTML)
        assert(html.contains("<ul><li>상위 업무<ul><li>하위 업무<ul><li>상세 업무</li></ul></li><li>두 번째 하위</li></ul></li><li>다음 상위</li></ul>"), html)

        let mixed = "1. 계획\n   - 요구사항\n   - [x] 검토\n2. 실행\n   1. 배포\n   2. 점검"
        let nested = withoutAnchors(MarkdownPreviewCore.render(mixed).html)
        assert(nested.contains("<ol><li>계획<ul>"), nested)
        assert(nested.contains("<input type='checkbox' disabled checked> 검토"), nested)
        assert(nested.contains("<li>실행<ol>"), nested)
        assert(nested.contains("<li>점검</li>"), nested)
        assert(withoutAnchors(MarkdownPreviewCore.render("5. 첫 항목\n6. 다음 항목").html).hasPrefix("<ol start='5'>"))
        assert(MarkdownPreviewCore.render("- 안전한 <script>\n  - **중요**").html.contains("&lt;script&gt;"))

        let original = "- 상위\n- 하위\n"
        let lowerLocation = ("- 상위\n- " as NSString).length
        guard let indented = MarkdownIndentCore.change(in: original,
                selection: NSRange(location: lowerLocation, length: 0), outdent: false) else {
            fatalError("Tab indentation returned nil")
        }
        let withChild = (original as NSString).replacingCharacters(in: indented.range, with: indented.replacement)
        assert(withChild == "- 상위\n  - 하위\n", withChild)
        assert(withoutAnchors(MarkdownPreviewCore.render(withChild).html).contains("<li>상위<ul><li>하위"))
        guard let outdented = MarkdownIndentCore.change(in: withChild,
                selection: NSRange(location: lowerLocation + 2, length: 0), outdent: true) else {
            fatalError("Shift-Tab outdent returned nil")
        }
        assert((withChild as NSString).replacingCharacters(in: outdented.range, with: outdented.replacement) == original)
        // Multiple selected lines: ending selection exactly at the next line's
        // start must never move that third line.
        let many = "- A\n- B\n- C\n"
        let changed = MarkdownIndentCore.change(in: many,
            selection: NSRange(location: 0, length: ("- A\n- B\n" as NSString).length), outdent: false)!
        assert((many as NSString).replacingCharacters(in: changed.range, with: changed.replacement) == "  - A\n  - B\n- C\n")
        let orderedParent = "10. 상위\n- 하위\n"
        let oPlace = ("10. 상위\n- 하위" as NSString).length
        let adjusted = MarkdownIndentCore.change(in: orderedParent,
            selection: NSRange(location: oPlace, length: 0), outdent: false)!
        let orderedChild = (orderedParent as NSString).replacingCharacters(in: adjusted.range, with: adjusted.replacement)
        assert(orderedChild == "10. 상위\n    - 하위\n", orderedChild)
        assert(withoutAnchors(MarkdownPreviewCore.render(orderedChild).html).contains("<ol start='10'><li>상위<ul><li>하위"))
        assert(MarkdownIndentCore.nextListPrefix(after: "  - [x] 완료") == "  - [ ] ")
        assert(MarkdownIndentCore.nextListPrefix(after: "9. 검사") == "10. ")
        assert(MarkdownIndentCore.nextListPrefix(after: "- ") == "")
        assert(MarkdownIndentCore.nextListPrefix(after: "본문") == nil)

        let math = "본문\n$$\n\\frac{a}{b}\n$$\n"
        let mathCaret = ("본문\n$$\n\\frac{" as NSString).length
        assert(MarkdownContextCore.context(in: math, utf16Offset: mathCaret) == .math)
        assert(MarkdownContextCore.context(in: math, utf16Offset: (math as NSString).length) == .normal)
        let mermaid = "```mermaid\nflowchart TD\n  A --> B\n```\n"
        assert(MarkdownContextCore.context(in: mermaid,
            utf16Offset: ("```mermaid\nflowchart" as NSString).length) == .mermaid)
        assert(MarkdownContextCore.context(in: mermaid,
            utf16Offset: (mermaid as NSString).length) == .normal)
        assert(MarkdownContextCore.context(in: "```text\n$$\nabc", utf16Offset: 15) == .code)
        assert(MarkdownContextCore.context(in: "```latex\n\\alpha", utf16Offset: 15) == .math)
        assert(MarkdownContextCore.context(in: "```markmap\n# 업무", utf16Offset: 16) == .normal)
        assert(MarkdownContextCore.context(in: "~~~mermaid\nflowchart TD", utf16Offset: 21) == .mermaid)
        assert(MarkdownPreviewCore.render("~~~text\n**literal**\n~~~").html.contains("<pre><code>**literal**</code></pre>"))
        assert(MarkdownPreviewCore.render("    - 문자 그대로", mode: .standard).html.contains("<pre><code>- 문자 그대로</code></pre>"))
        assert(!MarkdownPreviewCore.render("    일반 문장", mode: .memo).html.contains("<pre>"))
        assert(!MarkdownPreviewCore.render("    - 문자 그대로", mode: .standard).html.contains("<ul>"))
        for snippet in MarkdownAssistSnippet.allCases {
            assert(!snippet.source.isEmpty)
            assert(snippet.caretBack >= 0 && snippet.caretBack <= (snippet.source as NSString).length)
        }
        let fraction = MarkdownAssistSnippet.fraction
        let numerator = (fraction.source as NSString).length - fraction.caretBack
        assert((fraction.source as NSString).substring(with: NSRange(location: numerator, length: 1)) == "a")
        let inlineInsert = MarkdownInsertRequest(source: fraction.source, caretBack: fraction.caretBack,
                                                  inlineSnippet: true)
        assert(inlineInsert.inlineSnippet && inlineInsert.source == fraction.source)
        assert(!MarkdownTemplates.insertion(for: .equation).inlineSnippet)
        assert(MarkdownAssistSnippet.node.context == .mermaid)
        assert(MarkdownAssistSnippet.squareRoot.context == .math)
        assert(MarkdownPreviewCore.render("```mermaid\nflowchart TD\n A[진행] --> B[완료]\n```").html.contains("<svg"))
        // Regression: legitimate Markdown source must never be rewritten by rendering.
        let raw = "- [x] 한글 ✅\n  - 하위 **강조**\n\n$$\nx^2\n$$"
        _ = MarkdownPreviewCore.render(raw)
        assert(raw == "- [x] 한글 ✅\n  - 하위 **강조**\n\n$$\nx^2\n$$")
        print("PASS stage 2: GFM nested tasks/ordered lists, Tab/Shift-Tab, Enter continuation, fence-aware LaTeX/Mermaid contextual templates, UTF-16 and source safety")
    }
}
