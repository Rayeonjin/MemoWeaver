import Foundation

// Live preview has two independently bounded stages:
// 1) a short idle delay capped during uninterrupted typing; and
// 2) a serialized, cancellable-before-start Markdown-to-HTML render.
// This prevents an older long render from overwriting a newer edit, while
// letting the reader see progress even when no 550ms pause occurs.
enum MemoWeaverPreviewPolicy {
    static let idleDelay: TimeInterval = 0.14
    static let maximumWait: TimeInterval = 0.40

    static func delay(firstChangeAt: TimeInterval, now: TimeInterval) -> TimeInterval {
        let elapsed = max(0, now - firstChangeAt)
        return min(idleDelay, max(0, maximumWait - elapsed))
    }

    // The HTML contains a *JavaScript selector* referring to diagrams even
    // when the note has none. Only the actual generated wrapper authorizes
    // running the 5MB offline Mermaid/Markmap engine in WKWebView.
    static func needsOfficialDiagramEngine(_ html: String) -> Bool {
        html.contains("<div class='workos-official-diagram'")
    }
}

// Opt-in stage timing for macOS troubleshooting. Logs only stage names,
// durations and source lengths (never note titles or content). Normal app
// launches do not write these diagnostics.
enum MemoWeaverPreviewDiagnostics {
    static let enabled = ProcessInfo.processInfo.environment["MEMOWEAVER_PREVIEW_TRACE"] == "1"

    static func record(_ stage: String, startedAt: TimeInterval, sourceLength: Int = 0) {
        guard enabled else { return }
        let ms = (Date.timeIntervalSinceReferenceDate - startedAt) * 1_000
        let line = String(format: "[MemoWeaver Preview] %@ %.1fms sourceChars=%d\n",
                          stage, ms, sourceLength)
        if let bytes = line.data(using: .utf8) { FileHandle.standardError.write(bytes) }
    }
}

actor MemoWeaverPreviewRenderer {
    static let shared = MemoWeaverPreviewRenderer()

    // No await within this actor method: only one conversion runs at a time.
    // Cancelled requests waiting for the actor are discarded before parsing.
    func render(title: String, noteDate: String, status: String,
                markdown: String, mode: MarkdownPreviewMode) -> String? {
        guard !Task.isCancelled else { return nil }
        let start = Date.timeIntervalSinceReferenceDate
        let html = NoteDocuments.markdownPreviewHTML(title: title, noteDate: noteDate,
                                                     status: status, markdown: markdown, mode: mode)
        MemoWeaverPreviewDiagnostics.record("markdown-to-html", startedAt: start,
                                              sourceLength: markdown.count)
        return html
    }
}
