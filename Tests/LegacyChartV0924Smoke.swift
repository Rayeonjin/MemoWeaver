import Foundation

func escapeHTML(_ text: String) -> String {
    text.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}

@main
struct LegacyChartV0924Smoke {
    static func check(_ ok: @autoclosure () -> Bool, _ message: String) {
        if !ok() { fputs("FAIL: \(message)\n", stderr); exit(1) }
    }
    static func preview(_ json: String, language: String = "vega-lite") -> String {
        MarkdownPreviewCore.render("```\(language)\n\(json)\n```").html
    }
    static func main() {
        let valid = #"{"data":{"values":[{"month":"1월","value":12},{"month":"2월","value":28}]},"mark":"bar","encoding":{"x":{"field":"month"},"y":{"field":"value"}}}"#
        let html = preview(valid)
        check(html.contains("<svg"), "Inline Vega-Lite bar should render via tiny legacy SVG")
        check(html.contains("legacy-chart"), "Legacy chart is explicitly marked")
        check(html.contains("1월") && html.contains("2월"), "Unicode categories survive")
        check(html.contains("<rect "), "Generated bars are present")
        check(preview(valid, language: "vegalite").contains("<svg"), "Historic alias supported")

        let line = valid.replacingOccurrences(of: "\"mark\":\"bar\"", with: "\"mark\":\"line\"")
        check(!preview(line).contains("<svg"), "Unsupported marks must not be misrendered")
        check(preview(line).contains("&quot;mark&quot;"), "Unsupported specs show escaped source")
        let tooLong = " " + String(repeating: "x", count: 65_000) + valid
        check(!preview(tooLong).contains("<svg"), "Oversized JSON not parsed")
        let negative = valid.replacingOccurrences(of: "\"value\":12", with: "\"value\":-12")
        check(!preview(negative).contains("<svg"), "Negative legacy values rejected")
        let empty = #"{"data":{"values":[]},"mark":"bar","encoding":{"x":{"field":"month"},"y":{"field":"value"}}}"#
        check(!preview(empty).contains("<svg"), "Empty chart falls back")
        let attack = valid.replacingOccurrences(of: "1월", with: "<script>alert(1)</script>")
        let safe = preview(attack)
        check(safe.contains("<svg"), "Malicious label still valid JSON but SVG-escaped")
        check(!safe.contains("<script>"), "Untrusted labels are escaped")
        check(safe.contains("&lt;script&gt;"), "Escaped label retained")
        check(!preview("<script>alert(1)</script>").contains("<script>"), "Invalid JSON escaped")

        let mermaid = MarkdownTemplates.insertion(for: .chart).source
        check(mermaid.contains("```mermaid") && mermaid.contains("xychart-beta"), "New charts use Mermaid only")
        check(!mermaid.contains("vega-lite"), "No legacy authoring template")
        let plain = MarkdownPreviewCore.render("이것은 평범한 메모입니다.").html
        check(!plain.contains("legacy-chart"), "No legacy work for ordinary memo")
        print("PASS v0.9.24: read-only bounded legacy Vega bar preview, safety and Mermaid-first authoring")
    }
}
