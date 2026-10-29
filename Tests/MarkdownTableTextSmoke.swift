import Foundation

@main struct MarkdownTableTextSmoke {
    static func main() {
        func converted(_ text: String, marker: String) -> MarkdownTableTextCore.Conversion? {
            let ns = text as NSString
            let index = ns.range(of: marker).location
            return MarkdownTableTextCore.conversion(in: text, selection: NSRange(location: index, length: 0))
        }
        func expect(_ label: String, _ actual: String?, _ expected: String) {
            guard actual == expected else {
                fputs("FAIL \(label): \(String(describing: actual)) != \(expected)\n", stderr)
                exit(1)
            }
            print("PASS \(label)")
        }
        let table = "개요\n\n| 월 | 판매량 |\n| --- | ---: |\n| 1월 | 12 |\n| 2월 | 28 |\n\n후기"
        let tsv = "월\t판매량\n1월\t12\n2월\t28"
        let result = converted(table, marker: "2월")
        expect("Korean table into TSV", result?.tsv, tsv)
        let ns = table as NSString
        expect("only table range is replaced", result.map { ns.replacingCharacters(in: $0.range, with: $0.tsv) },
               "개요\n\n" + tsv + "\n\n후기")
        let escaped = "| 설명 | 수량 | 비고 |\n|:---|:---:|---:|\n| A\\|B | 3 | 앞<br>뒤 |\n| C |  | \"메모\" |"
        expect("escaped pipes, blank columns, br, quotes", converted(escaped, marker: "A\\|B")?.tsv,
               "설명\t수량\t비고\nA|B\t3\t\"앞\n뒤\"\nC\t\t\"\"\"메모\"\"\"")
        let tableStart = ns.range(of: "| 월").location
        let tableEnd = ns.range(of: "| 2월 | 28 |").location + ("| 2월 | 28 |" as NSString).length
        let includesBreak = MarkdownTableTextCore.conversion(in: table,
            selection: NSRange(location: tableStart, length: tableEnd + 1 - tableStart))
        expect("full-table selection includes trailing newline", includesBreak?.tsv, tsv)
        let selectProse = MarkdownTableTextCore.conversion(in: table,
            selection: NSRange(location: 0, length: (table as NSString).length))
        assert(selectProse == nil, "Must refuse selection spanning prose")
        print("PASS prose is not rewritten")
        assert(converted("| A | B |\n| 1 | 2 |", marker: "1") == nil)
        print("PASS no valid divider")
        let fenced = "```markdown\n| A | B |\n| --- | --- |\n| 1 | 2 |\n```"
        assert(converted(fenced, marker: "1") == nil)
        print("PASS fenced code unchanged")
        let wide = "| 첫 | 둘 | 셋 |\n| --- | --- | --- |\n| 1 |  | 3 |"
        expect("empty middle cell", converted(wide, marker: "첫")?.tsv, "첫\t둘\t셋\n1\t\t3")
        let second = "| 첫 | 둘 |\n| --- | --- |\n| 1 | 2 |\n\n| 셋 | 넷 |\n| --- | --- |\n| 3 | 4 |"
        expect("nearest table", converted(second, marker: "셋")?.tsv, "셋\t넷\n3\t4")
        print("PASS Markdown table conversion suite")
    }
}
