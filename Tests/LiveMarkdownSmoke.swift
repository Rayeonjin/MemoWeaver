import Foundation

@main
struct LiveMarkdownSmoke {
    static func main() {
        func inline(_ text: String, _ style: LiveMarkdown.InlineKind, _ payload: String) {
            guard let match = LiveMarkdown.inline(in: text, caret: (text as NSString).length) else {
                fatalError("Missing inline shortcut in: \(text)")
            }
            guard match.kind == style else { fatalError("Incorrect inline kind: \(text)") }
            let original = text as NSString
            assert(original.substring(with: match.contentRange) == payload, "Incorrect UTF-16 range for \(text)")
            assert(NSMaxRange(match.range) == original.length, "Match should end at cursor")
        }
        inline("회의에서 **중요한 결론**", .bold, "중요한 결론")
        inline("표준 __강조__", .bold, "강조")
        inline("지금 *검토 중*", .italic, "검토 중")
        inline("오늘 _최종안_", .italic, "최종안")
        inline("예전 ~~중단된 작업~~", .strikethrough, "중단된 작업")
        inline("명령어 `swiftc`", .code, "swiftc")
        inline("🐱‍💻 기록 [레퍼런스](https://example.com/wiki?q=1)", .link("https://example.com/wiki?q=1"), "레퍼런스")
        assert(LiveMarkdown.inline(in: "아직 **미완성", caret: ("아직 **미완성" as NSString).length) == nil)
        assert(LiveMarkdown.inline(in: "원문 plain", caret: ("원문 plain" as NSString).length) == nil)
        let blockCases: [(String, String, LiveMarkdown.BlockKind)] = [
            ("# ", "", .heading(1)), ("## ", "", .heading(2)), ("### ", "", .heading(3)),
            ("> ", "", .quote), ("- ", "• ", .bullet), ("* ", "• ", .bullet),
            ("- [ ] ", "☐ ", .checklist(false)), ("- [x] ", "☑ ", .checklist(true)),
            ("1. ", "1. ", .numbered)
        ]
        for (source, replacement, kind) in blockCases {
            let text = "이전 줄\n" + source
            let caret = (text as NSString).length
            guard let parsed = LiveMarkdown.block(in: text, caret: caret) else {
                fatalError("Missing block shortcut for \(source)")
            }
            assert(parsed.replacement == replacement && parsed.kind == kind)
            assert((text as NSString).substring(with: parsed.range) == source)
        }
        assert(LiveMarkdown.block(in: "##", caret: 2) == nil)
        assert(LiveMarkdown.continuation(after: "• 메모")?.prefix == "• ")
        assert(LiveMarkdown.continuation(after: "• ")?.empty == true)
        assert(LiveMarkdown.continuation(after: "☑ 확인")?.prefix == "☐ ")
        assert(LiveMarkdown.continuation(after: "15. 작업")?.prefix == "16. ")
        assert(LiveMarkdown.continuation(after: "999. 한계") == nil)
        print("PASS: Korean/emoji UTF-16, live inline formatting, headings/lists/quotes, checkbox, return continuation")
    }
}
