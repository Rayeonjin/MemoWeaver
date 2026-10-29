import Foundation

@main struct MarkdownEditorHighlightSmoke {
    static func main() {
        let source = #"""
        # 제목 😊
        - [x] 체크
        12. 번호
        > 인용
        다음 **강조** *기울임* [링크](https://example.com) `**코드**` $x^2$
        $$
        \frac{a}{b}
        $$
        ```mermaid
        # 코드 속 제목 아님
        - 코드 속 목록 아님
        ```
        문서 마지막 👩🏽‍💻
        """#
        let original = source
        let ns = source as NSString
        let spans = MarkdownEditorHighlightCore.spans(in: source)
        func tokens(_ kind: MarkdownEditorHighlightCore.Kind) -> [String] {
            spans.filter { $0.kind == kind }.map { ns.substring(with: $0.range) }
        }
        precondition(tokens(.heading) == ["# 제목 😊"], "Fenced '# ...' must not become heading")
        precondition(tokens(.listMarker) == ["-", "12."], "List markers only, not content")
        precondition(tokens(.checkbox) == ["[x]"])
        precondition(tokens(.quoteMarker) == [">"])
        precondition(tokens(.link) == ["[링크](https://example.com)"])
        precondition(tokens(.inlineCode) == ["`**코드**`"])
        precondition(tokens(.emphasisMarker).filter { $0 == "**" }.count == 2,
                     "Code span must suppress nested emphasis coloring")
        precondition(tokens(.mathDelimiter).filter { $0 == "$$" }.count == 2)
        precondition(tokens(.mathDelimiter).filter { $0 == "$" }.count == 2)
        precondition(tokens(.fence).count == 2)
        precondition(spans.allSatisfy { $0.range.location >= 0 && $0.range.length > 0 &&
            NSMaxRange($0.range) <= ns.length })
        precondition(source == original, "Syntax highlighting must never mutate Markdown source")

        let windows = "# 제목🧠\r\n- [ ] 확인 👩🏽‍💻\r\n끝"
        let spansCRLF = MarkdownEditorHighlightCore.spans(in: windows)
        let windowsNSString = windows as NSString
        let checkbox = spansCRLF.first { $0.kind == .checkbox }!
        precondition(windowsNSString.substring(with: checkbox.range) == "[ ]")
        precondition(checkbox.range.location == ("# 제목🧠\r\n- " as NSString).length)

        let longFence = "~~~markmap\n# inside\n~~~~\n# outside"
        let outside = MarkdownEditorHighlightCore.spans(in: longFence).filter { $0.kind == .heading }
        precondition(outside.count == 1)
        precondition((longFence as NSString).substring(with: outside[0].range) == "# outside")
        print("PASS Markdown syntax ranges: UTF-16 Korean/emoji, CRLF, code fences, math, lists, links, no source edits")
    }
}
