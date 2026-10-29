import Foundation
func escapeHTML(_ text: String) -> String {
    text.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}
@main
struct VisualStageSmoke {
    static func main() {
        let source = """
        ```markmap
        # 업무 분석
        ## 기획
        - 목표
        - 일정
        ## 실행
        - 담당자 & 책임
        - 점검 내용
          - 하위 할 일
        ## 결과
        - 수치 확인
        ```
        """
        let rendered = MarkdownPreviewCore.render(source).html
        assert(rendered.contains("diagram-markmap"))
        assert(rendered.contains("C") && rendered.contains("stroke-linecap='round'"))
        assert(rendered.contains("#4b7bd6") && rendered.contains("#13a28e"))
        assert(rendered.contains("fill='#273f69'"))
        assert(rendered.contains("&amp; 책임") && !rendered.contains("담당자 & 책임"))
        assert(rendered.contains("min-width:"))
        assert(!rendered.contains("viewBox='0 0 1100"))

        let chain = "flowchart LR\nA[시작] --> B{결정}\nB -->|예| C[완료]\nB -.-> D[재검토]\nD --> B"
        guard let flow = MermaidFlowchart.svg(chain) else { fatalError("Common flowchart not rendered") }
        assert(flow.contains("stroke-linecap='round'"))
        assert(flow.contains("marker-end='url(#workos-mermaid-arrow)'"))
        assert(flow.contains(" C") && flow.contains("#64748b"))
        assert(flow.contains("stroke-dasharray='5 5'"), "Dotted edges need a dotted stroke")
        assert(flow.contains("viewBox='0 0 635 "), "Feedback must not collapse all nodes to depth zero")
        assert(MermaidFlowchart.svg("graph TD\nA==>B")?.contains("stroke-width='3'") == true)
        assert(MermaidFlowchart.svg("flowchart TD\nA---B")?.contains("stroke-width='1.8'") == true)
        assert(MermaidFlowchart.svg("sequenceDiagram\n A->>B: hello") == nil)
        let unsafe = MermaidFlowchart.svg("flowchart TD\nA[<svg onload=bad>] --> B")!
        assert(unsafe.contains("&lt;svg onload=bad&gt;"))
        assert(!unsafe.contains("<svg onload=bad>"))
        assert(source.hasPrefix("```markmap"), "Rendering must not mutate its source")
        print("PASS visual stage: branching colored Markmap, smooth Mermaid flowchart arrows, feedback layers and HTML escaping")
    }
}
