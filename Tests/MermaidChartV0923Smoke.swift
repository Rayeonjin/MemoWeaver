import Foundation
// The production helper is in Storage.swift; this isolated renderer smoke
// uses the same escaping contract without loading the user's database.
func escapeHTML(_ text: String) -> String {
    text.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}

@main
struct MermaidChartV0923Smoke {
    static func check(_ ok: @autoclosure () -> Bool, _ message: String) {
        if !ok() { fputs("FAIL: \(message)\n", stderr); exit(1) }
    }

    static func main() {
        for kind in MermaidChartTemplates.Kind.allCases {
            let request = MermaidChartTemplates.insertion(for: kind)
            let source = request.source
            check(source.hasPrefix("```mermaid\n"), "Mermaid fence: \(kind.rawValue)")
            check(source.hasSuffix("```\n"), "Mermaid closes fence")
            check(!source.contains("vega-lite"), "No Vega-Lite writer")
            let caret = (source as NSString).length - request.caretBack
            check(caret >= 0 && caret < (source as NSString).length, "Caret within source")
            let chartSource = source.components(separatedBy: "\n").dropFirst().dropLast().joined(separator: "\n")
            check(WorkOSOfficialDiagramRuntime.chartType(for: chartSource) == (kind == .pie ? "pie" : "xy"), "Chart classifier")
            let preview = MarkdownPreviewCore.render(source).html
            check(preview.contains("data-workos-diagram='mermaid'"), "Official diagram anchor")
            check(preview.contains("data-workos-chart='\(kind == .pie ? "pie" : "xy")'"), "Responsive chart anchor")
            check(preview.contains("&quot;1월&quot;") || kind == .pie, "Quoted Korean x labels")
            let context = MarkdownContextCore.context(in: source, utf16Offset: (source as NSString).length - 5)
            check(context == (kind == .pie ? .mermaidPie : .mermaidXY), "Chart editor context")
        }
        let chart = MarkdownTemplates.insertion(for: .chart)
        check(chart.source.contains("xychart-beta"), "Default insert toolbar uses Mermaid")
        check(WorkOSOfficialDiagramRuntime.chartType(for: "---\nconfig:\n  xyChart:\n    showDataLabel: true\n---\nxychart\n  x-axis [\"1월\"]") == "xy", "Frontmatter chart header")
        check(WorkOSOfficialDiagramRuntime.chartType(for: "flowchart TD\nA-->B") == nil, "Flowchart untouched")
        let historic = "```vega-lite\n{\"data\": {\"values\": []}, \"mark\": \"bar\"}\n```"
        let oldHTML = MarkdownPreviewCore.render(historic).html
        check(oldHTML.contains("legacy-chart"), "Historical Vega source explained")
        check(oldHTML.contains("&quot;data&quot;"), "Historical JSON escaped for display")
        check(!oldHTML.contains("<svg"), "Unsupported empty Vega data stays fallback")
        let malicious = MarkdownPreviewCore.render("```vega-lite\n<script>alert(1)</script>\n```").html
        check(!malicious.contains("<script>"), "Historical source cannot inject HTML")
        check(MarkdownContextCore.context(in: "```mermaid\nflowchart TD\nA-->B", utf16Offset: 34) == .mermaid, "Flowchart tools preserved")
        check(MarkdownAssistSnippet.xyBar.context == .mermaidXY, "XY palette context")
        check(MarkdownAssistSnippet.pieSlice.context == .mermaidPie, "Pie palette context")
        print("PASS v0.9.23 Mermaid chart templates, editor context, safe legacy fallback, responsive metadata")
    }
}
