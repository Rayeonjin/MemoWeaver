import Foundation

// Isolated renderer test: synthetic input only, no user DB or WebKit.
func escapeHTML(_ value: String) -> String {
    value.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}

@main
struct MarkdownPreviewFixSmoke {
    static func main() {
        let common = """
        ```mermaid
        flowchart TD
          A[시작] --> B{확인} -->|예| C[완료]
          B -- 아니오 --> D[재검토]
        ```
        """
        let commonHTML = MarkdownPreviewCore.render(common).html
        assert(commonHTML.contains("<svg"), "Standard chained Mermaid flowchart must render")
        assert(commonHTML.contains("완료") && commonHTML.contains("재검토"))
        assert(commonHTML.contains("예") && commonHTML.contains("아니오"))
        assert(!commonHTML.contains("diagram-fallback"))

        let compact = "flowchart LR; A[시작]-->B[분석]; B-->C[종료]"
        let compactSVG = MermaidFlowchart.svg(compact)
        assert(compactSVG != nil, "Semicolon-delimited Mermaid flowcharts must render")
        assert(compactSVG!.range(of: #"width:[0-9]+px;height:[0-9]+px"#, options: .regularExpression) != nil)
        assert(!compactSVG!.contains("width:100%"), "Mermaid must not fill the preview width")
        assert(MermaidFlowchart.svg("graph BT\n  A-->B") != nil)
        assert(MermaidFlowchart.svg("flowchart RL\n  A --> B") != nil)
        assert(MermaidFlowchart.svg("flowchart TB\n  A-.->B") != nil)
        assert(MermaidFlowchart.svg("flowchart TD\n  A ==> B") != nil)
        assert(MermaidFlowchart.svg("flowchart TD\n  A --o B") != nil)
        assert(MermaidFlowchart.svg("flowchart TD\n  A[\"검토; 보류\"] --> B") != nil)
        let subgraph = MermaidFlowchart.svg("flowchart TD\nsubgraph grp\n A --> B\nend\nstyle A fill:#fff")
        assert(subgraph?.contains("diagram-note") == true)
        let injection = MermaidFlowchart.svg("flowchart TD\nA[<script>alert(1)</script>] --> B")!
        assert(injection.contains("&lt;script&gt;") && !injection.contains("<script>"))
        assert(MermaidFlowchart.svg("sequenceDiagram\n A->>B: hi") == nil,
               "Unsupported types must not be silently fabricated")

        let markmap = """
        ```markmap
        # 업무 분석
        ## 준비
        - 데이터 수집
        - 점검 항목
        ## 실행
        - 아주 긴 한국어 항목은 기존처럼 중간에 잘려서는 안 됩니다
        ```
        """
        let markHTML = MarkdownPreviewCore.render(markmap).html
        assert(markHTML.contains("Markmap 기본 계층도"))
        assert(markHTML.contains("font-size='15'"))
        assert(markHTML.contains("min-width:"))
        assert(!markHTML.contains("viewBox='0 0 1100"), "Must size to actual diagram, not fixed 1100px")
        assert(markHTML.contains("잘려서는"))
        assert(!markHTML.contains("<pre># 업무 분석"), "Markdown code must not be shown as a visible preformatted source block")
        print("PASS preview patch: Mermaid flowchart chains/labels/directions/semicolons; safe unsupported fallback; natural-size Markmap")
    }
}
