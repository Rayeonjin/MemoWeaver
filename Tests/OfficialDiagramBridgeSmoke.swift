import Foundation
func escapeHTML(_ text: String) -> String {
    text.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}

@main struct OfficialDiagramBridgeSmoke {
    static func main() {
        let tricky = "flowchart LR\n A[한글 & <x> ' \" 테스트] --> B[완료]"
        let wrapped = WorkOSOfficialDiagramRuntime.wrapper(
            kind: "mermaid", source: tricky, fallback: "<svg id='fallback'></svg>")
        precondition(wrapped.contains("data-workos-diagram='mermaid'"))
        precondition(wrapped.contains("data-workos-source='flowchart LR"))
        precondition(wrapped.contains("&amp; &lt;x&gt; &#39; &quot;"))
        precondition(!wrapped.contains("<x>"))
        precondition(wrapped.contains("<svg id='fallback'></svg>"))
        let markup = """
        ```markmap
        # 계획
        ## 조사
        - 항목 1
        - 항목 2
        ```

        ```mermaid
        sequenceDiagram
           Alice->>Bob: ping
           Bob-->>Alice: pong
        ```
        """
        let preview = MarkdownPreviewCore.render(markup)
        precondition(preview.html.contains("data-workos-diagram='markmap'"))
        precondition(preview.html.contains("data-workos-diagram='mermaid'"))
        precondition(preview.html.contains("<svg")) // original fallback preserved
        precondition(preview.html.contains("sequenceDiagram")) // unsupported source preserved
        precondition(!preview.html.contains("src='http") && !preview.html.contains("href='http") && !preview.html.contains("https://"))
        precondition(WorkOSOfficialDiagramRuntime.embedForStandaloneExport("<body>safe</body>") == "<body>safe</body>")
        print("PASS official diagram bridge: source escaped, fallback kept, Mermaid/Markmap anchors, no remote URLs")
    }
}
