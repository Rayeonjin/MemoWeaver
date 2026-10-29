import Foundation

@main
struct HTMLColorStylesSmoke {
    static func main() {
        let html = """
        <html><head><style type="text/css">
        p.p1 {margin: 0px; color: #000000} span.s1 {font: 16px Arial; color: #FF3B30}
        span.s2 {color: #2266cc;} span.s3 {color: #060606}
        .s4 { color:#123ABC; } body {color: #CCCCCC}
        </style></head><body><p class="p1">본문 <span class="s1">빨강</span> <span class="s2">파랑</span> <span class="s3">검정</span> <span class="s4" style="font-weight:bold">지정</span></p></body></html>
        """
        let prepared = RichHTMLColorStyles.inlineForegroundColors(in: html)
        assert(prepared.contains("class=\"p1\" style=\"color: #000000\""))
        assert(prepared.contains("class=\"s1\" style=\"color: #FF3B30\""))
        assert(prepared.contains("class=\"s2\" style=\"color: #2266CC\""))
        assert(prepared.contains("class=\"s3\" style=\"color: #060606\""))
        assert(prepared.contains("style=\"font-weight:bold; color: #123ABC\""))
        let inline = #"<span class="s1" style="color: #13579B">선명한 글씨</span>"#
        assert(RichHTMLColorStyles.inlineForegroundColors(in: "<style>.s1{color:#f00}</style>" + inline).contains(inline),
               "Existing inline color must win over CSS")
        let hostile = #"<style>.s1 { background-image: url(https://host.test/x); color: #E91E63; }</style><span class="s1">안전</span>"#
        let output = RichHTMLColorStyles.inlineForegroundColors(in: hostile)
        assert(output.contains("style=\"color: #E91E63\""))
        assert(!String(output[output.range(of: "<span")!.lowerBound...]).contains("background-image:"))
        assert(RichHTMLColorStyles.inlineForegroundColors(in: "<p>한글</p>") == "<p>한글</p>")
        print("PASS HTML color CSS: Cocoa classes are converted to safe inline colors without overwriting source")
    }
}
