import Foundation

// This deliberately mocks the HTML assembly boundary. The real AppKit/WebKit
// bridge is only compilable on macOS; the scheduling policy and serialized
// renderer must also be executable on Linux during packaging QA.
enum MarkdownPreviewMode: String, Sendable { case memo, standard }
enum NoteDocuments {
    static func markdownPreviewHTML(title: String, noteDate: String, status: String,
                                    markdown: String, mode: MarkdownPreviewMode) -> String {
        "\(title)|\(noteDate)|\(status)|\(markdown)|\(mode.rawValue)"
    }
}

@main struct PreviewPipelineV0954Smoke {
    static func main() async {
        func close(_ a: TimeInterval, _ b: TimeInterval) -> Bool { abs(a - b) < 0.000_01 }
        precondition(close(MemoWeaverPreviewPolicy.delay(firstChangeAt: 10, now: 10), 0.14))
        precondition(close(MemoWeaverPreviewPolicy.delay(firstChangeAt: 10, now: 10.30), 0.10))
        precondition(close(MemoWeaverPreviewPolicy.delay(firstChangeAt: 10, now: 10.40), 0))
        precondition(close(MemoWeaverPreviewPolicy.delay(firstChangeAt: 10, now: 11.00), 0))
        precondition(!MemoWeaverPreviewPolicy.needsOfficialDiagramEngine("<script>document.querySelectorAll('[data-workos-diagram=mermaid]')</script>"))
        precondition(!MemoWeaverPreviewPolicy.needsOfficialDiagramEngine("<div>Plain note with math: $x^2$</div>"))
        precondition(MemoWeaverPreviewPolicy.needsOfficialDiagramEngine("<article><div class='workos-official-diagram' data-workos-source='foo'></div></article>"))
        // Burst simulation: one key every 40ms for 1.2s. Each burst must
        // publish no later than the 400ms bound even without a typing pause.
        var first: TimeInterval? = nil
        var published: [TimeInterval] = []
        for tick in 0...30 {
            let t = Double(tick) * 0.04
            if first == nil { first = t }
            let delay = MemoWeaverPreviewPolicy.delay(firstChangeAt: first!, now: t)
            if delay < 0.000_01 {
                published.append(t)
                first = nil
            }
        }
        precondition(published.count >= 2)
        precondition(close(published[0], 0.4))
        let renderer = MemoWeaverPreviewRenderer.shared
        let output = await renderer.render(title: "Title", noteDate: "2026-10-28",
            status: "active", markdown: "**hello**", mode: .memo)
        precondition(output == "Title|2026-10-28|active|**hello**|memo")
        print("PASS v0.9.54: 140ms idle/400ms max, lazy diagram engine, serialized renderer")
    }
}
