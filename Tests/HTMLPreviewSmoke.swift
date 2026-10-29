import Foundation

@main
struct HTMLPreviewSmoke {
    static func main() throws {
        let cocoaHTML = """
        <html><head><meta charset="utf-8"/><style type="text/css">
        p.p1 {margin: 0.0px 0.0px 0.0px 0.0px; font: 13.3px Arial; color: #000000}
        span.s1 {text-decoration: underline}
        </style></head><body>
        <p class="p1"><span class="s1">업무 인수인계</span></p>
        <p class="p2">이슈 대응 &amp; 재점검</p>
        </body></html>
        """
        let untitled = WorkNote.from(["id":"html-preview", "title":"", "body":cocoaHTML])
        assert(untitled.bodyHTML == cocoaHTML, "Original HTML must not be changed")
        assert(untitled.visibleTitle == "업무 인수인계", "Untitled note must use the actual body text")
        assert(untitled.plainBody.contains("이슈 대응 & 재점검"))
        assert(!untitled.plainBody.contains("p.p1") && !untitled.plainBody.contains("span.s1"))
        assert(!untitled.plainBody.contains("13.3px"), "CSS should never appear in the preview")

        // Some imported documents include a <style> block without a <head>.
        let external = "<STYLE media='all'>p.p1 {font: 17px Helvetica}</STYLE><p>진짜 메모</p>"
        assert(HTMLText.plain(external) == "진짜 메모")
        // Scripts and comments are not visible document content either.
        let withScript = "<!-- hidden --> <div>보이는 내용</div><script>throw 'secret';</script>"
        let extracted = HTMLText.plain(withScript)
        assert(extracted.contains("보이는 내용") && !extracted.contains("secret"))
        // Literal code typed by the user is escaped; unlike a real stylesheet,
        // it is intentional visible text and must remain searchable.
        let literal = HTMLText.plain("<p>&lt;style&gt;p.p1 {color:red}&lt;/style&gt;</p>")
        assert(literal.contains("<style>p.p1 {color:red}</style>"))
        assert(HTMLText.plain("<h2>회의 목적</h2><p>한글 내용</p>").contains("한글 내용"))
        assert(WorkNote.from(["body":"<head><style>p.p1{}</style></head>"]).visibleTitle == "새 메모")
        print("PASS HTML preview: Cocoa CSS removed, body/title preserved, old note raw HTML unchanged")
    }
}
