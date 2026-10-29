import Foundation

// Minimal HTML helper for standalone Foundation-only renderer tests.
func escapeHTML(_ text: String) -> String {
    text.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}

@main
struct MarkdownStage4Smoke {
    static func main() {
        let raw = "# 오늘의 일\n\n- 첫째\n  - 둘째\n    - 셋째\n\n$$\na+b\n$$\n\n```mermaid\nflowchart TD\n A-->B\n```\n"
        let rendered = MarkdownPreviewCore.render(raw)
        // Source positions are for scroll targeting only; source is untouched.
        assert(rendered.html.contains("data-md-line='1'"))
        assert(rendered.html.contains("data-md-line='3'"))
        assert(rendered.html.contains("<li data-md-line='4'>둘째"))
        assert(rendered.html.contains("<li data-md-line='5'>셋째"))
        assert(rendered.html.contains("data-md-line='7'"))
        assert(rendered.html.contains("data-md-line='11'"))
        assert(rendered.hasMath)
        assert(rendered.html.contains("<svg"))
        assert(raw == "# 오늘의 일\n\n- 첫째\n  - 둘째\n    - 셋째\n\n$$\na+b\n$$\n\n```mermaid\nflowchart TD\n A-->B\n```\n")
        // Caret focus uses the same UTF-16 offsets as NSTextView, not Swift
        // character indices. Emoji is two UTF-16 code units.
        let sample = "😀첫줄\n한글\n끝"
        let starts = EditorLineNumberRules.lineStarts(in: sample)
        assert(starts == [0, 5, 8], "Unexpected UTF16 starts: \(starts)")
        assert(EditorLineNumberRules.lineIndex(forUTF16Offset: 4, starts: starts) + 1 == 1)
        assert(EditorLineNumberRules.lineIndex(forUTF16Offset: 5, starts: starts) + 1 == 2)
        assert(EditorLineNumberRules.lineIndex(forUTF16Offset: 8, starts: starts) + 1 == 3)
        print("PASS v0.9.4: preview source anchors, nested list mapping, math/diagram, UTF-16 caret position")
    }
}
