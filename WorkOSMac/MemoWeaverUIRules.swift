import Foundation

// Pure, testable text statistics and UI-content rules. No AppKit, AI, database,
// network, or storage mutations. NSTextView selection offsets are UTF-16.
enum MemoWeaverUIRules {
    static func titleSuggestion(_ text: String) -> String {
        // Do not split an entire 10,000-line source on every keypress.
        let snippet = String(text.prefix(3000))
        let first = snippet.split(whereSeparator: \.isNewline)
            .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            .map(String.init) ?? ""
        let stripped = first.replacingOccurrences(of: #"^\s*#{1,6}\s+"#,
                                                   with: "", options: .regularExpression)
        return stripped.isEmpty ? "새 메모" : String(stripped.prefix(70))
    }

    static func totalLines(in text: String) -> Int {
        EditorLineNumberRules.lineStarts(in: text).count
    }

    static func column(in text: String, utf16Offset: Int, lineStart: Int) -> Int {
        let ns = text as NSString
        let offset = min(ns.length, max(0, utf16Offset))
        let start = min(offset, max(0, lineStart))
        return ns.substring(with: NSRange(location: start, length: offset - start)).count + 1
    }

    // An empty active query never filters out a note.
    static func matchesNote(title: String, excerpt: String, term: String) -> Bool {
        let q = term.trimmingCharacters(in: .whitespacesAndNewlines)
        return q.isEmpty || title.localizedStandardContains(q) || excerpt.localizedStandardContains(q)
    }
}

// Apply only inside WKWebView previews, never to persisted Markdown or HTML/PDF
// exports. The Mermaid/Markmap canvas remains light to preserve source contrast.
enum MemoWeaverPreviewAppearance {
    static func apply(_ html: String, dark: Bool) -> String {
        guard dark, let range = html.range(of: "</head>", options: .caseInsensitive) else { return html }
        let css = """
        <style id='memoweaver-preview-dark'>
        :root{color-scheme:dark}
        html,body{background:#171b21!important;color:#e5e9f0!important}
        a{color:#88b5ff!important}
        blockquote{color:#b6c3d3!important;border-left-color:#526178!important}
        .metadata,.diagram-note{color:#a6b0be!important}
        pre{background:#242d39!important;color:#e5e9f0!important}
        pre[data-language]::before{color:#a6b0be!important}
        mark{background:#66511f!important;color:#fff0bd!important}
        .formula{background:#252e39!important;color:#e5e9f0!important}
        .workos-table td,.workos-table th{border-color:#4c5867!important}
        .workos-table th{background:#2c3745!important}
        .callout{background:#27374b!important;color:#e5e9f0!important}
        .section{border-top-color:#4c5867!important}
        .diagram,.workos-official-diagram,.diagram-markmap,
        .workos-official-target.markmap-view{background:#fff!important;color:#182337!important;border-radius:8px}
        .diagram-fallback{color:#182337!important;background:#fff8e1!important}
        .diagram-fallback pre{color:#182337!important;background:#f3f4f6!important}
        </style>
        """
        var output = html
        output.insert(contentsOf: css, at: range.lowerBound)
        return output
    }
}

// Only useful high-signal status is always visible in the narrow sidebar.
// Full timestamps, the SQLite path, and backup diagnostics are behind Info.
enum MemoWeaverStorageStatus {
    static func needsAttention(_ status: String) -> Bool {
        ["실패", "오류", "확인 필요", "점검 필요"].contains(where: status.contains)
    }

    static func title(for status: String) -> String {
        if needsAttention(status) { return "저장 확인 필요" }
        if status.contains("저장 중") || status.contains("준비 중") { return "저장 중" }
        return "이 Mac에 저장"
    }

    static func symbol(for status: String) -> String {
        if needsAttention(status) { return "exclamationmark.triangle.fill" }
        if status.contains("저장 중") || status.contains("준비 중") { return "arrow.triangle.2.circlepath" }
        return "checkmark.circle.fill"
    }
}
