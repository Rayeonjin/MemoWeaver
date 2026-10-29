import Foundation

@main
struct SlashContextSmoke {
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() { fputs("FAIL: \(message)\n", stderr); exit(1) }
    }

    static func command(_ source: String) -> (SlashCommandCore.Trigger, MarkdownEditingContext)? {
        MarkdownSlashContextCore.trigger(in: source, caretUTF16: (source as NSString).length)
    }

    static func inserted(_ source: String, using item: SlashCommandCore.Item,
                         context: MarkdownEditingContext) -> (String, Int) {
        guard let (trigger, _) = command(source) else { fatalError("missing slash trigger") }
        let ns = source as NSString
        let lineStart = ns.lineRange(for: NSRange(location: trigger.range.location, length: 0)).location
        let linePrefix = ns.substring(with: NSRange(location: lineStart, length: trigger.range.location - lineStart))
        let prepared = SlashCommandCore.prepare(item, contextIsNormal: context == .normal,
                                                linePrefix: linePrefix)
        let result = ns.replacingCharacters(in: trigger.range, with: prepared.source)
        let offset = trigger.range.location + (prepared.source as NSString).length - prepared.caretBack
        check(offset >= 0 && offset <= (result as NSString).length, "valid caret")
        return (result, offset)
    }

    static func main() {
        check(SlashCommandCore.featured.count == 20, "17 discoverable syntax helpers")
        check(SlashCommandCore.items.count == 27, "24 commands total, including preserved basics")
        check(SlashCommandCore.matches("").count == 20, "no silent 8-item menu truncation")
        check(SlashCommandCore.matches("제목 1").contains(where: { $0.id == "h1" }), "heading still searchable")
        check(SlashCommandCore.matches("체크").contains(where: { $0.id == "check" }), "checklist still searchable")
        check(SlashCommandCore.matches("각주").contains(where: { $0.id == "footnote" }), "footnote accessible")
        check(SlashCommandCore.matches("mermaid").count >= 4, "multiple diagram templates")
        check(SlashCommandCore.matches("없는결과").isEmpty, "query filtering")
        check(SlashCommandCore.matches("", limit: 3).count == 3, "explicit limit still respected")
        for item in SlashCommandCore.items {
            check(item.caretBack >= 0 && item.caretBack <= (item.source as NSString).length,
                  "normal caret offset: \(item.id)")
        }
        check(command("업무 정리 /각주")?.1 == .normal, "prose slash command")
        check(command("문자열 😀 /표")?.1 == .normal, "emoji UTF-16 offset")
        check(command("https://example.com/foo") == nil, "URL must remain literal")
        check(command("문서/2026") == nil, "file path must remain literal")
        check(command("\\/") == nil, "escaped slash must remain literal")
        check(command("//") == nil, "double slash must remain literal")
        check(command("`echo /") == nil, "inline code slash stays literal")
        check(command("$x /분수") == nil, "inline math slash stays literal")
        check(command("| 내용 | /표") == nil, "table cell slash stays literal")

        check(MarkdownSlashContextCore.trigger(in: "열린 /", caretUTF16: 3) == nil,
              "slash not yet typed at caret")
        let inline = SlashCommandCore.matches("링크").first { $0.id == "link" }!
        check(!SlashCommandCore.prepare(inline, contextIsNormal: true,
                                        linePrefix: "내용 ").source.hasPrefix("\n"),
              "inline commands do not break prose")
        let block = SlashCommandCore.matches("표").first { $0.id == "table" }!
        check(SlashCommandCore.prepare(block, contextIsNormal: true,
                                       linePrefix: "기존 문장 ").source.hasPrefix("\n\n"),
              "block template separates from prose")

        let math = "메모 😀\n$$\n  /분수"
        check(command(math)?.1 == .math, "display math offers math commands")
        check(MarkdownSlashContextCore.matches("분수", context: .math).contains(where: { $0.id == "fraction" }),
              "existing math assist reused")
        let fraction = MarkdownSlashContextCore.matches("분수", context: .math).first!
        let (fractionInserted, fracCaret) = inserted(math, using: fraction, context: .math)
        check(fractionInserted.contains("  \\frac{a}{b}"), "raw fraction insertion")
        check((fractionInserted as NSString).substring(with: NSRange(location: fracCaret, length: 1)) == "a",
              "caret focuses numerator")
        check(command("```latex\n/행렬")?.1 == .math, "latex fence offers math")
        check(command("~~~tex\n/극한")?.1 == .math, "tex tilde fence offers math")
        check(command("$$\nx^2 /분수") == nil, "no slash popup in the middle of expression")
        check(MarkdownSlashContextCore.matches("", context: .math).count > 25,
              "all math snippets scrollable")

        let mermaid = "```mermaid\nflowchart TD\n  /분기"
        check(command(mermaid)?.1 == .mermaid, "Mermaid fence offers diagram commands")
        let branch = MarkdownSlashContextCore.matches("분기", context: .mermaid).first!
        let (branchInserted, branchCaret) = inserted(mermaid, using: branch, context: .mermaid)
        check(branchInserted.contains("  A{조건} -->|예| B\n  A -->|아니오| C"),
              "multiline Mermaid branch respects indentation")
        check((branchInserted as NSString).substring(with: NSRange(location: branchCaret, length: 1)) == "조",
              "Mermaid caret inside first placeholder")
        check(command("```mermaid\nxychart-beta\n  /막대값")?.1 == .mermaidXY,
              "XY chart slash offers XY commands")
        check(command("```mermaid\npie showData\n  /원형")?.1 == .mermaidPie,
              "pie chart slash offers pie commands")
        check(MarkdownSlashContextCore.matches("막대값", context: .mermaidXY).contains(where: { $0.id == "xyBar" }),
              "XY bar code insertion")
        check(MarkdownSlashContextCore.matches("원형 항목", context: .mermaidPie).contains(where: { $0.id == "pieSlice" }),
              "pie slice code insertion")
        check(!MarkdownSlashContextCore.matches("분기", context: .mermaidXY).contains(where: { $0.id == "branch" }),
              "No flowchart branch tool inside XY chart")
        check(SlashCommandCore.matches("차트").count >= 4,
              "All four Mermaid chart templates can be searched")
        check(command("~~~mermaid\n/노드")?.1 == .mermaid, "tilde Mermaid fence")
        check(command("```mermaid\nA --> B /연결") == nil, "no popup in edge label")
        check(MarkdownSlashContextCore.matches("", context: .mermaid).count >= 8,
              "existing Mermaid snippets scrollable")

        check(command("```swift\n/표") == nil, "no popup in generic code")
        check(command("```markmap\n/표") == nil, "no popup in Markmap content")
        check(command("```markdown\n/표") == nil, "no popup in fenced raw Markdown")
        check(command("```latex\n/분수\n```\n/표")?.1 == .normal,
              "normal menu resumes after closing code fence")
        check(command("$$\n/분수\n$$\n/표")?.1 == .normal,
              "normal menu resumes after closing math")
        check(command("```mermaid\n/분기\n```\n/표")?.1 == .normal,
              "normal menu resumes after closing Mermaid")
        check(command("## 제목\n/차트")?.1 == .normal, "Markdown normal menu")
        check(MarkdownSlashContextCore.matches("", context: .code).isEmpty,
              "generic fenced code has no commands")
        for context in [MarkdownEditingContext.math, .mermaid] {
            for item in MarkdownSlashContextCore.matches("", context: context) {
                check(item.caretBack >= 0 && item.caretBack <= (item.source as NSString).length,
                      "contextual caret offset for \(item.id)")
            }
        }
        print("PASS v0.9.13: 20 featured + 7 searchable basic commands, no 8-item truncation")
        print("PASS contextual math/Mermaid snippets, nested fences and literal slash protections")
        print("PASS UTF-16 Hangul/emoji caret, multiline Mermaid indentation, plain source preservation")
    }
}
