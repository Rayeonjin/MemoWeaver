import Foundation

// All document rendering runs locally. There are no CDN dependencies and
// no third-party fonts; KaTeX is bundled in MathML-only mode.
enum NoteDocuments {
    static let localKaTeX: String = {
        guard let path = Bundle.main.path(forResource: "katex-mathml", ofType: "js"),
              let code = try? String(contentsOfFile: path, encoding: .utf8) else { return "" }
        return code
    }()

    static func safeHTML(_ source: String) -> String {
        var html = source
        // NSTextView serializes rich text as a complete HTML document. Extract
        // only its body to prevent nested html/head/body tags in the export.
        if let bodyStart = html.range(of: #"(?is)<body\b[^>]*>"#, options: .regularExpression),
           let bodyEnd = html.range(of: #"(?is)</body>"#, options: .regularExpression),
           bodyStart.upperBound <= bodyEnd.lowerBound {
            html = String(html[bodyStart.upperBound..<bodyEnd.lowerBound])
        }
        let disallowed = [
            #"(?is)<\s*(script|iframe|object|embed|svg|video|audio|form|style)\b[^>]*>.*?<\s*/\s*\1\s*>"#,
            #"(?is)<\s*(img|link|meta|input|base|iframe|object|embed)\b[^>]*>"#,
            #"(?i)\bon[a-z]+\s*=\s*(['\"]).*?\1"#,
            #"(?i)\bon[a-z]+\s*=\s*[^\s>]+"#,
            #"(?i)javascript\s*:"#,
            #"(?i)url\s*\([^)]*\)"#,
            #"(?i)@import\b[^;]*;"#
        ]
        for pattern in disallowed {
            html = html.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        return html
    }

    private static func escapeAttribute(_ text: String) -> String {
        escapeHTML(text).replacingOccurrences(of: "'", with: "&#39;")
    }

    static func blockHTML(_ block: WorkBlock) -> String {
        let source = block.source
        switch block.kind {
        case .table: return WorkOSTable.html(source)
        case .equation:
            return "<div class='formula' data-tex='\(escapeAttribute(source))'><code>\(escapeHTML(source))</code></div>"
        case .mermaid:
            let fallback: String
            if let svg = MermaidFlowchart.svg(source) {
                fallback = "<div class='diagram'>\(svg)</div>"
            } else {
                fallback = "<div class='diagram-fallback'><p>공식 렌더러가 아직 준비되지 않았거나 이 문법을 표시할 수 없습니다. 원문은 보존됩니다.</p><pre>\(escapeHTML(source))</pre></div>"
            }
            return WorkOSOfficialDiagramRuntime.wrapper(kind: "mermaid", source: source, fallback: fallback)
        }
    }

    static func previewHTML(_ block: WorkBlock) -> String {
        wrappingHTML(title: "미리보기", body: blockHTML(block), includeMath: block.kind == .equation)
    }

    static func wrappingHTML(title: String, body: String, includeMath: Bool) -> String {
        let mathScript = includeMath ? localKaTeX : ""
        let script = includeMath ? """
        <script>\(mathScript)</script>
        <script>
          for (const el of document.querySelectorAll('.formula, .formula-inline')) {
            if (window.WorkOSKaTeX) {
              try { el.innerHTML = WorkOSKaTeX.renderToString(el.getAttribute('data-tex'),
                 { displayMode:el.classList.contains('formula'), output:'mathml', throwOnError:false, trust:false,
                   strict:'warn', maxExpand:200, maxSize:25 }); }
              catch(e) { el.textContent = el.getAttribute('data-tex'); }
            }
          }
          window.WorkOSReady = true;
        </script>
        """ : "<script>window.WorkOSReady=true;</script>"
        return """
        <!doctype html><html lang='ko'><head><meta charset='utf-8'>
        <meta name='viewport' content='width=device-width, initial-scale=1'>
        <meta http-equiv='Content-Security-Policy' content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data: blob:; font-src data:; connect-src 'none'; media-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'">
        <title>\(escapeHTML(title))</title>
        <style>
        :root{color-scheme:light dark}html,body{margin:0;padding:0;}
        body{font:14px/1.68 -apple-system,BlinkMacSystemFont,'Apple SD Gothic Neo',sans-serif;
             background:#fff;color:#182337;padding:22px 26px;overflow-wrap:anywhere;}
        h1{font-size:25px}h2{font-size:21px}h3{font-size:17px}
        h1,h2,h3{line-height:1.3;margin:20px 0 10px}
        p{margin:7px 0}blockquote{border-left:3px solid #94a3b8;padding-left:12px;color:#475569}
        /* Markdown specifies hierarchy, not a 40px-per-level visual indent.
           Keep nested lists readable in a narrow split pane. */
        article ul,article ol{padding-inline-start:1.35em;margin:5px 0 6px}
        article li ul,article li ol{padding-inline-start:1.15em;margin:3px 0 4px}
        article li{margin:2px 0;line-height:1.5}
        .md-block{scroll-margin-top:70px}
        code,pre{font-family:ui-monospace,SFMono-Regular,monospace}
        pre{white-space:pre-wrap;background:#f3f4f6;padding:12px;border-radius:7px;overflow-x:auto;}
        /* A language badge is visual metadata, not executable or remote code. */
        pre[data-language]{position:relative;padding-top:30px;}
        pre[data-language]::before{content:attr(data-language);position:absolute;right:10px;top:6px;
            color:#64748b;font:11px/1.4 -apple-system,BlinkMacSystemFont,sans-serif;letter-spacing:.02em}
        mark{background:#fff0a3;color:inherit;border-radius:2px;padding:0 2px;}
        a{color:#2563eb} .metadata{color:#64748b;font-size:12px;margin-bottom:25px}
        .workos-table{border-collapse:collapse;width:100%;table-layout:fixed;margin:14px 0 20px}
        .workos-table td,.workos-table th{border:1px solid #cbd5e1;padding:9px 12px;text-align:left;vertical-align:top;word-break:break-word}
        .workos-table th{background:#f1f5f9;font-weight:650}
        .formula{overflow-x:auto;text-align:center;padding:18px 8px;min-height:45px;background:#f8fafc;border-radius:7px;}
        .formula math{font-size:1.3em}
        .formula-inline math{font-size:1.1em;vertical-align:middle}
        .callout{border-left:3px solid #4b87be;background:#eff6ff;padding:11px 13px;border-radius:5px;margin:12px 0}
        .callout p{margin:5px 0}
        details.callout summary{cursor:pointer;font-weight:650;list-style-position:inside;}
        details.callout[open] summary{margin-bottom:6px}
        .md-link{text-decoration:underline;text-decoration-style:dotted}
        hr{border:0;border-top:1px solid #cbd5e1;margin:15px 0}
        .diagram{max-width:100%;overflow-x:auto;padding:12px 3px;}
        .diagram-markmap{box-sizing:border-box;border:1px solid #e5ecf5;border-radius:12px;
             background:linear-gradient(135deg,#fcfdff,#f8fbff);padding:14px 10px;}
        .diagram-markmap svg{font-family:-apple-system,BlinkMacSystemFont,'Apple SD Gothic Neo',sans-serif;}
        .diagram-note{font-size:12px;color:#64748b;margin:5px 0}
        .workos-official-diagram{max-width:100%;margin:10px 0;min-width:0;overflow:auto;}
        .workos-official-target{display:none;min-width:0;overflow:auto}
        .workos-official-diagram[data-official-rendered='1']>.workos-official-target{display:block}
        .workos-official-diagram[data-official-rendered='1']>.workos-native-diagram{display:none}
        .workos-official-target:not(.markmap-view) svg{max-width:none!important;height:auto;display:block;margin:0}
        .workos-official-target.markmap-view{height:440px;overflow:hidden;border-radius:12px;background:#f8fafc}
        .workos-official-target.markmap-view svg{width:100%;height:100%;max-width:none}
        .workos-official-target .markmap{width:100%;height:100%}
        .diagram-fallback{padding:12px;background:#fff8e1;border-radius:7px}
        .memo-image{display:block;max-width:100%;height:auto;object-fit:contain;border-radius:5px;margin:10px auto}
        .memo-image-missing{display:block;color:#ad531e;border:1px dashed #d6a477;padding:10px;border-radius:5px}
        .section{margin-top:24px;border-top:1px solid #e2e8f0;padding-top:5px;page-break-inside:avoid}
        @media print{body{padding:20px 25px}.section{break-inside:avoid}}
        </style></head><body>\(body)\(script)\(WorkOSOfficialDiagramRuntime.mermaidNaturalSizeScript)</body></html>
        """
    }

    // Same offline renderer as HTML/PDF export, but with unsaved editor values.
    // Preview never writes back to the note or mutates the stored source.
    static func livePreviewHTML(title: String, noteDate: String, status: String,
                                bodyHTML: String, blocks: [WorkBlock]) -> String {
        let heading = "<h1>\(escapeHTML(title))</h1>"
        let meta = "<div class='metadata'>\(escapeHTML(noteDate)) · \(escapeHTML(status))</div>"
        var body = heading + meta + "<article>\(safeHTML(bodyHTML))</article>"
        for block in blocks {
            body += "<section class='section'><h2>\(escapeHTML(block.kind.title))</h2>\(blockHTML(block))</section>"
        }
        return wrappingHTML(title: title, body: body,
                            includeMath: blocks.contains(where: { $0.kind == .equation }))
    }

    static func markdownPreviewHTML(title: String, noteDate: String, status: String,
                                    markdown: String, mode: MarkdownPreviewMode? = nil) -> String {
        let rendered = MarkdownPreviewCore.render(markdown, mode: mode ?? .preferred)
        let heading = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "<h1>\(escapeHTML(title))</h1>"
        let meta = "<div class='metadata'>\(escapeHTML(noteDate)) · \(escapeHTML(status)) · Markdown</div>"
        let safeBody = MemoWeaverAttachments.resolvePreviewImages(rendered.html)
        return wrappingHTML(title: title.isEmpty ? "Markdown 메모" : title,
                            body: heading + meta + "<article>" + safeBody + "</article>",
                            includeMath: rendered.hasMath)
    }

    static func html(note: WorkNote) -> String {
        if note.isMarkdown {
            return WorkOSOfficialDiagramRuntime.embedForStandaloneExport(
                markdownPreviewHTML(title: note.title, noteDate: note.noteDate,
                                    status: note.status, markdown: note.bodyHTML))
        }
        return WorkOSOfficialDiagramRuntime.embedForStandaloneExport(
            livePreviewHTML(title: note.visibleTitle, noteDate: note.noteDate, status: note.status,
                            bodyHTML: note.bodyHTML, blocks: note.workosBlocks))
    }

    static func markdown(note: WorkNote) -> String {
        if note.isMarkdown { return note.bodyHTML } // byte-for-byte source
        // Before first edit, exporting Markdown must match what the user sees
        // in the unified plain-text editor, not include Cocoa's HTML wrapper.
        return LegacyNoteTextConverter.editableText(for: note)
    }

    // Prefer CommonMark for ordinary rich text; preserve complex HTML rather
    // than silently discarding styling or contents that cannot be represented.
    static func htmlToMarkdown(_ raw: String) -> String {
        var value = safeHTML(raw)
        value = value.replacingOccurrences(of: #"(?is)<head\b[^>]*>.*?</head>"#, with: "", options: .regularExpression)
        if value.range(of: "<table", options: [.caseInsensitive]) != nil ||
           value.range(of: "<div[^>]*style=", options: [.caseInsensitive,.regularExpression]) != nil {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let replacements: [(String,String)] = [
            (#"(?is)<br\s*/?>"#, "\n"),
            (#"(?is)<h1\b[^>]*>"#, "\n# "), (#"(?is)<h2\b[^>]*>"#, "\n## "),
            (#"(?is)<h3\b[^>]*>"#, "\n### "),
            (#"(?is)</h[1-6]>"#, "\n\n"),
            (#"(?is)<li\b[^>]*>"#, "\n- "), (#"(?is)</li>"#, ""),
            (#"(?is)<(strong|b)\b[^>]*>"#, "**"), (#"(?is)</(strong|b)>"#, "**"),
            (#"(?is)<(em|i)\b[^>]*>"#, "*"), (#"(?is)</(em|i)>"#, "*"),
            (#"(?is)<code\b[^>]*>"#, "`"), (#"(?is)</code>"#, "`"),
            (#"(?is)<(p|div|blockquote)\b[^>]*>"#, "\n"),
            (#"(?is)</(p|div|blockquote)>"#, "\n\n"),
            (#"(?is)</?(html|body|ul|ol|span|font)[^>]*>"#, ""),
        ]
        for (regex, replacement) in replacements {
            value = value.replacingOccurrences(of: regex, with: replacement, options: .regularExpression)
        }
        // Retain unfamiliar tags as raw HTML (legal in Markdown), avoid data loss.
        let entities = [("&lt;","<"),("&gt;",">"),("&quot;","\""),("&#39;","'"),("&nbsp;"," "),("&amp;","&")]
        for (a,b) in entities { value = value.replacingOccurrences(of: a, with: b) }
        value = value.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
