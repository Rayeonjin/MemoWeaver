import Foundation

@main
struct PasteTableSmoke {
    static func main() {
        let korean = "업무\t담당\t상태\r\n서버 점검\t김철수\t완료\r\n오류 분석\t이영희\t진행 중\r\n"
        let expected = "업무\t담당\t상태\n서버 점검\t김철수\t완료\n오류 분석\t이영희\t진행 중\n"
        assert(WorkOSPasteTable.tabDelimitedText(from: korean) == expected)
        assert(WorkOSPasteTable.tabDelimitedText(from: "A\tB") == "A\tB")
        assert(WorkOSPasteTable.tabDelimitedText(from: "합계\t\t23\r행 2\t\t") == "합계\t\t23\n행 2\t\t")
        assert(WorkOSPasteTable.tabDelimitedText(from: "\"다음\n줄\"\t\"따옴표\"\r\n") == "\"다음\n줄\"\t\"따옴표\"\n")
        assert(WorkOSPasteTable.tabDelimitedText(from: "일반 문장\n다음 줄") == nil)
        assert(WorkOSPasteTable.tabDelimitedText(from: "\t\t \n") == nil)

        // macOS Excel can offer an HTML table without plain TSV, especially
        // when the selected range is a single column or includes merged cells.
        let html = """
        <html><head><style>td { font: 12px Arial; }</style></head>
        <body><table><tbody>
          <tr><td><span>업무</span></td><th>담당</th><th>상태</th></tr>
          <tr><td>서버 &amp; 보안</td><td>김철수</td><td>완료</td></tr>
          <tr><td>오류 &lt;조사&gt;</td><td>이영희</td><td>진행 중</td></tr>
        </tbody></table></body></html>
        """
        let htmlTSV = "업무\t담당\t상태\n서버 & 보안\t김철수\t완료\n오류 <조사>\t이영희\t진행 중"
        assert(WorkOSPasteTable.htmlTableText(from: html) == htmlTSV)
        assert(WorkOSPasteTable.preferredText(plain: "줄바꿈뿐", tabular: nil, html: html) == htmlTSV)
        assert(WorkOSPasteTable.preferredText(plain: "A\tB", tabular: "X\tY", html: html) == "X\tY")
        assert(WorkOSPasteTable.preferredText(plain: "A\tB", tabular: nil, html: html) == "A\tB")
        assert(WorkOSPasteTable.htmlTableText(from: "<table><tr><td>한 열</td></tr><tr><td>두 번째 줄</td></tr></table>")
            == "한 열\n두 번째 줄")
        assert(WorkOSPasteTable.htmlTableText(from:
            "<table><tr><td rowspan=2>팀</td><td colspan=2>A&amp;B</td></tr><tr><td>진행</td><td>상태</td></tr></table>")
            == "팀\tA&B\t\n\t진행\t상태")
        assert(WorkOSPasteTable.htmlTableText(from:
            "<table><tr><td>줄&lt;1&gt;<br/>줄 2</td><td>&quot;완료&quot;</td></tr></table>")
            == "\"줄<1>\n줄 2\"\t\"\"\"완료\"\"\"")
        assert(WorkOSPasteTable.preferredText(plain: "일반 문장", tabular: nil, html: "<p>일반 문장</p>") == nil)

        // UTF-16 ranges: a Korean/emoji prefix must not corrupt the position.
        let before = "시작😀\n<선택 부분>\n끝"
        let original = before as NSString
        let selected = (original as String).range(of: "<선택 부분>")!
        let selection = NSRange(selected, in: before)
        let afterward = original.replacingCharacters(in: selection, with: expected)
        let affected = WorkOSPasteTable.insertedRange(selection: selection,
            previousLength: original.length, currentLength: (afterward as NSString).length)
        assert(affected == NSRange(location: selection.location, length: (expected as NSString).length))
        assert(WorkOSPasteTable.stillMatches(document: afterward, range: affected!, pastedText: expected))
        assert(!WorkOSPasteTable.stillMatches(document: afterward + "추가", range: NSRange(location: affected!.location+1, length: affected!.length), pastedText: expected))
        let converted = (afterward as NSString).replacingCharacters(in: affected!, with: "A\tB\nC\tD")
        assert(converted == "시작😀\nA\tB\nC\tD\n끝")

        assert(WorkOSPasteTable.insertedRange(selection: NSRange(location: 0, length: 0),
            previousLength: 0, currentLength: 5) == NSRange(location: 0, length: 5))
        assert(WorkOSPasteTable.insertedRange(selection: NSRange(location: 2, length: 9),
            previousLength: 6, currentLength: 11) == nil)
        assert(WorkOSPasteTable.insertedRange(selection: NSRange(location: 2, length: 0),
            previousLength: 6, currentLength: 6) == nil)
        assert(!WorkOSPasteTable.stillMatches(document: "abc", range: NSRange(location: 2, length: 5), pastedText: "x"))
        print("PASS: Excel TSV/HTML/merged cells/single column/Hangul/UTF-16 region/adjacent text")
    }
}
