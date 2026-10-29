import Foundation

// v0.9.8: pure Swift synthetic notes only; never reads a user's database.
@main
struct MarkdownMemoSmoke {
    static func html(_ text: String, mode: MarkdownPreviewMode = .memo) -> String {
        MarkdownPreviewCore.render(text, mode: mode).html
    }
    static func applied(_ source: String, _ change: MarkdownIndentCore.Change) -> String {
        (source as NSString).replacingCharacters(in: change.range, with: change.replacement)
    }
    static func main() {
        let multi = "끝.\n끝"
        assert(html(multi).contains("<p>끝.<br>끝</p>"))
        assert(html(multi, mode: .standard).contains("<p>끝. 끝</p>"))
        assert(html("첫 문장\n둘째 문장\n\n다음 문단").contains("<p>첫 문장<br>둘째 문장</p>"))
        assert(html("첫 문장\n둘째 문장\n\n다음 문단").contains("<p>다음 문단</p>"))
        assert(html("문단1\n\n\n\n문단2").components(separatedBy: "<p>").count == 3)
        assert(html("**줄을\n넘는 강조**").contains("<strong>줄을<br>넘는 강조</strong>"))
        assert(html("**줄을\n넘는 강조**", mode: .standard).contains("<strong>줄을 넘는 강조</strong>"))
        assert(html("문장  \n다음", mode: .standard).contains("<p>문장<br>다음</p>"))
        assert(html("문장\\\n다음", mode: .standard).contains("<p>문장<br>다음</p>"))
        assert(html("문장\\\n다음").contains("<p>문장<br>다음</p>"))
        assert(!html("문장\\\n다음").contains("<br><br>"))
        assert(html("첫 줄\n    들여쓴 문장").contains("첫 줄<br>&#160;&#160;&#160;&#160;들여쓴 문장"))
        assert(!html("    그냥 들여쓴 문장").contains("<pre>"))
        assert(html("    코드 블록", mode: .standard).contains("<pre><code>코드 블록</code></pre>"))
        assert(html("제목\n#### 소제목").contains("<h4>소제목</h4>"))
        assert(html("본문\n---").contains("<hr>"))
        assert(html("일반\n- 목록").contains("<ul>"))
        assert(html("일반\n```\n코드\n```").contains("<pre><code>코드</code></pre>"))
        assert(html("일반\n$$\nx^2\n$$").contains("data-tex='x^2'"))
        assert(html("일반\n| A | B |\n| --- | --- |\n| 1 | 2 |").contains("<table"))

        let quote = html("> 인용 첫째\n> 인용 둘째")
        assert(quote.contains("<blockquote><p>인용 첫째<br>인용 둘째</p></blockquote>"), quote)
        let quoteStd = html("> 인용 첫째\n> 인용 둘째", mode: .standard)
        assert(quoteStd.contains("<blockquote><p>인용 첫째 인용 둘째</p></blockquote>"), quoteStd)
        let quoteBlank = html("> 첫 문단\n>\n> 둘째 문단")
        assert(quoteBlank.contains("<p>첫 문단</p><p>둘째 문단</p>"), quoteBlank)
        let callout = html("> [!IMPORTANT]\n> 첫째\n> 둘째")
        assert(callout.contains("<strong>IMPORTANT</strong><p>첫째<br>둘째</p>"), callout)
        let calloutStd = html("> [!TIP]\n> 첫째\n> 둘째", mode: .standard)
        assert(calloutStd.contains("<strong>TIP</strong><p>첫째 둘째</p>"), calloutStd)
        assert(html("악성 <script>\n다음 & 문장").contains("&lt;script&gt;<br>다음 &amp; 문장"))
        assert(!html("<img src=x onerror=alert(1)>").contains("<img"))
        assert(html("- 상위\n  - 하위").contains("<ul><li") &&
               html("- 상위\n  - 하위").contains("<li data-md-line='2'>하위"))
        assert(html("```mermaid\nflowchart TD\n A[가] --> B[나]\n```").contains("workos-official-diagram"))
        assert(html("```markmap\n# 항목\n- 내용\n```").contains("workos-official-diagram"))

        // Tab completes the marker before changing list depth.
        let marker = "-"
        let changeMarker = MarkdownIndentCore.change(in: marker,
            selection: NSRange(location: 1, length: 0), outdent: false)!
        assert(applied(marker, changeMarker) == "- ")
        assert(changeMarker.selection == NSRange(location: 2, length: 0))
        let bareOrdered = "10."
        let orderedMarker = MarkdownIndentCore.change(in: bareOrdered,
            selection: NSRange(location: 3, length: 0), outdent: false)!
        assert(applied(bareOrdered, orderedMarker) == "10. ")
        // Empty line directly following a list indents at the content column.
        let afterList = "- 상위\n"
        let blankIndent = MarkdownIndentCore.change(in: afterList,
            selection: NSRange(location: (afterList as NSString).length, length: 0), outdent: false)!
        assert(applied(afterList, blankIndent) == "- 상위\n  ")
        let ordinary = "일반\n"
        let regularIndent = MarkdownIndentCore.change(in: ordinary,
            selection: NSRange(location: (ordinary as NSString).length, length: 0), outdent: false)!
        assert(applied(ordinary, regularIndent) == "일반\n  ")
        let orderedParent = "10. 상위\n- 하위"
        let child = MarkdownIndentCore.change(in: orderedParent,
            selection: NSRange(location: (orderedParent as NSString).length, length: 0), outdent: false)!
        let nested = applied(orderedParent, child)
        assert(nested == "10. 상위\n    - 하위", nested)
        let dedent = MarkdownIndentCore.change(in: nested,
            selection: NSRange(location: (nested as NSString).length, length: 0), outdent: true)!
        assert(applied(nested, dedent) == orderedParent)
        let twoOrdered = "9. 이전\n10. 다음\n- 나중"
        let selectionEnd = ("9. 이전\n10. 다음\n" as NSString).length
        let selectTwo = MarkdownIndentCore.change(in: twoOrdered,
            selection: NSRange(location: 0, length: selectionEnd), outdent: false)!
        assert(applied(twoOrdered, selectTwo) == "    9. 이전\n    10. 다음\n- 나중")
        assert(MarkdownIndentCore.nextListPrefix(after: "9. 항목") == "10. ")
        assert(MarkdownIndentCore.nextListPrefix(after: "- ") == "")

        // Preview settings are never serialized into the note or exported .md.
        let raw = "한글✅\n이모지🌿\n\n```\n  원본  \n```"
        let memo = html(raw)
        let common = html(raw, mode: .standard)
        assert(memo != common && raw.contains("  원본  "))
        let note = WorkNote.from(["id": "memo-test", "title": "메모", "body": raw,
                                  "bodyFormat": "markdown"])
        assert(note.isMarkdown)
        assert(NoteDocuments.markdown(note: note) == raw)
        let key = MarkdownPreviewMode.defaultsKey
        let previous = UserDefaults.standard.object(forKey: key)
        defer {
            if let previous { UserDefaults.standard.set(previous, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
        UserDefaults.standard.set(MarkdownPreviewMode.memo.rawValue, forKey: key)
        let memoExport = NoteDocuments.html(note: note)
        assert(memoExport.contains("한글✅<br>이모지🌿"))
        UserDefaults.standard.set(MarkdownPreviewMode.standard.rawValue, forKey: key)
        let standardExport = NoteDocuments.html(note: note)
        assert(standardExport.contains("한글✅ 이모지🌿"))
        assert(NoteDocuments.markdown(note: note) == raw)
        print("PASS v0.9.8: memo/standard soft breaks, paragraphs, quotes, callouts, indent, lists, fences, tables, security, exported HTML preference and raw-source preservation")
    }
}
