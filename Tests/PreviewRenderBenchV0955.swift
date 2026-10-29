import Foundation

// Storage.swift normally owns this helper; the isolated benchmark intentionally
// does not compile or touch the user's SQLite database.
func escapeHTML(_ text: String) -> String {
    text.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&#39;")
}

// Synthetic documents only. Measures offline Markdown parser time, NOT WKWebView
// JavaScript, diagram layout, editing event latency, or a real Mac's memory.
@main struct PreviewRenderBenchV0955 {
    static func measure(_ label: String, source: String, rounds: Int) {
        let start = Date.timeIntervalSinceReferenceDate
        var outputBytes = 0
        for _ in 0..<rounds {
            let result = MarkdownPreviewCore.render(source, mode: .memo)
            outputBytes += result.html.utf8.count
        }
        let total = (Date.timeIntervalSinceReferenceDate - start) * 1000
        print(String(format: "%@: %.2f ms/render, %d output bytes, %d rounds",
                     label, total/Double(rounds), outputBytes/rounds, rounds))
    }
    static func main() {
        let paragraph = "업무 진행 내역을 정리합니다. **강조**와 [링크](https://example.com) 및 - 목록으로 구성합니다.\n"
        let normal = Array(repeating: paragraph, count: 150).joined(separator: "\n")
        let long = Array(repeating: paragraph, count: 600).joined(separator: "\n")
        let media = normal + "\n$$\nE = mc^2\n$$\n\n" +
            "```mermaid\nflowchart TD\n A[시작] --> B[종료]\n```\n\n" +
            "```markmap\n# 계획\n## 실행\n- 첫 항목\n- 둘째 항목\n```\n"
        measure("short (150 lines)", source: normal, rounds: 18)
        measure("long (600 lines)", source: long, rounds: 8)
        measure("mixed Math/Mermaid/Markmap", source: media, rounds: 18)
    }
}
