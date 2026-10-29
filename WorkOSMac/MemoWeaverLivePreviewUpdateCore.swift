import Foundation

// Live preview HTML is produced by NoteDocuments, not an external web page.
// Extract only the rendered header/article when the shell and rendering
// engines are unchanged. Keep the trusted CSS/JS shell alive in WKWebView.
struct MemoWeaverLivePreviewDocument: Equatable {
    let fragment: String
    let styleSignature: String
    let requiresMath: Bool
    let requiresDiagrams: Bool

    init?(html: String) {
        guard let body = html.range(of: "<body>", options: .caseInsensitive),
              let articleEnd = html.range(of: "</article>", options: [.caseInsensitive, .backwards]),
              body.upperBound <= articleEnd.lowerBound,
              let style = html.range(of: "<style", options: .caseInsensitive),
              let headEnd = html.range(of: "</head>", options: .caseInsensitive),
              style.lowerBound < headEnd.lowerBound else { return nil }
        fragment = String(html[body.upperBound..<articleEnd.upperBound])
        styleSignature = String(html[style.lowerBound..<headEnd.lowerBound])
        requiresMath = html.contains("WorkOSKaTeX.renderToString")
        requiresDiagrams = MemoWeaverPreviewPolicy.needsOfficialDiagramEngine(html)
    }
}

enum MemoWeaverLivePreviewUpdateCore {
    enum Action: Equatable { case reload, patch }

    static func action(currentStyle: String?, mathLoaded: Bool,
                       diagramsLoaded: Bool, incoming: MemoWeaverLivePreviewDocument?) -> Action {
        guard let incoming, let currentStyle,
              incoming.styleSignature == currentStyle,
              (!incoming.requiresMath || mathLoaded),
              (!incoming.requiresDiagrams || diagramsLoaded) else { return .reload }
        return .patch
    }
}
