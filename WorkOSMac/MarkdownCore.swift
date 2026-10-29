import Foundation

// Small offline Markdown primitives. Source remains plain UTF-8 text; all
// formatting is a reversible preview-only transformation. No network, HTML
// execution, attachment loading, or change to the legacy rich-text schema.
enum MarkdownPasteCore {
    // RFC 4180-like quoted TSV, including tabs/newlines/quotes inside cells.
    // Nil means retain the clipboard literally; NEVER drop unhandled cells.
    static func markdownTable(from tabSeparated: String) -> String? {
        let source = tabSeparated.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        guard source.contains("\t"), source.utf16.count <= 2_000_000 else { return nil }
        var rows: [[String]] = []
        var row: [String] = []
        var cell = ""
        let chars = Array(source)
        var i = 0
        var quoted = false
        while i < chars.count {
            let c = chars[i]
            if c == "\"" {
                if quoted && i + 1 < chars.count && chars[i + 1] == "\"" {
                    cell.append("\"")
                    i += 1
                } else if quoted || cell.isEmpty {
                    quoted.toggle()
                } else { cell.append(c) }
            } else if c == "\t" && !quoted {
                row.append(cell); cell = ""
            } else if c == "\n" && !quoted {
                row.append(cell); rows.append(row); row = []; cell = ""
            } else { cell.append(c) }
            i += 1
        }
        guard !quoted else { return nil }
        row.append(cell)
        if row.count > 1 || row.contains(where: { !$0.isEmpty }) { rows.append(row) }
        guard !rows.isEmpty, rows.count <= 300, (rows.map(\.count).max() ?? 0) <= 24 else { return nil }
        let columns = rows.map(\.count).max() ?? 0
        guard columns >= 2, rows.contains(where: { $0.contains(where: { !$0.isEmpty }) }) else { return nil }
        // Empty trailing columns and quoted multiline cells are intentionally
        // preserved, then flattened to a single Markdown table-cell string.
        func tableRow(_ row: [String]) -> String {
            "| " + (0..<columns).map { col in
                (col < row.count ? row[col] : "")
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "|", with: "\\|")
                    .replacingOccurrences(of: "\n", with: "<br>")
            }.joined(separator: " | ") + " |"
        }
        return ([tableRow(rows[0]), tableRow(Array(repeating: "---", count: columns))]
                + rows.dropFirst().map(tableRow)).joined(separator: "\n")
    }
}

struct MarkdownInsertRequest: Equatable {
    let id: UUID
    let source: String
    // The caret is placed this many UTF-16 positions before the inserted end.
    let caretBack: Int
    // In a math or Mermaid block, insert at the caret without adding blank lines.
    let inlineSnippet: Bool
    let wrapsSelection: Bool
    let beginsOnNewLine: Bool

    init(source: String, caretBack: Int, inlineSnippet: Bool = false,
         wrapsSelection: Bool = false, beginsOnNewLine: Bool = false) {
        id = UUID()
        self.source = source
        self.caretBack = caretBack
        self.inlineSnippet = inlineSnippet
        self.wrapsSelection = wrapsSelection
        self.beginsOnNewLine = beginsOnNewLine
    }
}

enum MarkdownTemplates {
    enum Kind: String, CaseIterable {
        case table, code, equation, mermaid, markmap, chart, diagram, callout, footnote
        var symbol: String {
            switch self {
            case .table: return "tablecells"
            case .code: return "chevron.left.forwardslash.chevron.right"
            case .equation: return "function"
            case .mermaid: return "arrow.triangle.branch"
            case .markmap: return "brain.head.profile"
            case .chart: return "chart.bar.xaxis"
            case .diagram: return "square.stack.3d.up"
            case .callout: return "text.bubble"
            case .footnote: return "text.quote"
            }
        }
        var title: String {
            switch self {
            case .table: return "표"
            case .code: return "코드 블록"
            case .equation: return "수식"
            case .mermaid: return "순서도"
            case .markmap: return "마인드맵"
            case .chart: return "차트"
            case .diagram: return "도식"
            case .callout: return "강조"
            case .footnote: return "각주"
            }
        }
    }
    static func insertion(for kind: Kind) -> MarkdownInsertRequest {
        let content: String
        let token: String
        switch kind {
        case .table:
            content = "| 항목 | 값 |\n| --- | --- |\n| 제목 | 10 |\n"
            token = "제목"
        case .code:
            content = "```text\n코드를 입력하세요\n```\n"
            token = "코드를 입력하세요"
        case .equation:
            content = "$$\nE = mc^2\n$$\n"
            token = "E = mc^2"
        case .mermaid:
            content = "```mermaid\nflowchart TD\n  A[시작] --> B[완료]\n```\n"
            token = "A[시작]"
        case .markmap:
            content = "```markmap\n# 프로젝트\n## 기획\n- 목표\n- 일정\n## 실행\n- 후속 작업\n```\n"
            token = "프로젝트"
        case .chart:
            return MermaidChartTemplates.insertion(for: .bar)
        case .diagram:
            return MermaidDiagramTemplates.insertion(for: .gantt)
        case .callout:
            content = "> [!IMPORTANT]\n> 중요한 내용을 적으세요.\n"
            token = "중요한 내용을 적으세요."
        case .footnote:
            content = "본문의 근거[^1]\n\n[^1]: 출처를 적으세요.\n"
            token = "출처를 적으세요."
        }
        let ns = content as NSString
        let match = ns.range(of: token)
        let back = match.location == NSNotFound ? 0 : ns.length - match.location
        return MarkdownInsertRequest(source: content, caretBack: back)
    }
}

// Memo-friendly preview is a display choice, never a stored-body migration.
// Standard remains available for imported Markdown that intentionally uses
// soft line breaks or four-space code blocks.
enum MarkdownPreviewMode: String, Sendable {
    case memo
    case standard

    static let defaultsKey = "memoryhome.markdown.previewMode"
    static var preferred: MarkdownPreviewMode {
        MarkdownPreviewMode(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .memo
    }
}

// Safe, intentionally bounded Markdown/GFM subset for local preview. Full
// CommonMark/Pandoc compatibility is out of scope for this first experiment.
enum MarkdownPreviewCore {
    struct Rendered { let html: String; let hasMath: Bool }

    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
    private static func capture(_ pattern: String, in text: String, group: Int = 1) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)),
              group < match.numberOfRanges,
              match.range(at: group).location != NSNotFound else { return nil }
        return (text as NSString).substring(with: match.range(at: group))
    }
    private static func replace(_ text: String, pattern: String, template: String) -> String {
        text.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
    }
    private static func inline(_ source: String, hasMath: inout Bool) -> String {
        var protected: [String] = []
        func token(_ html: String) -> String {
            protected.append(html)
            return "\u{E000}\(protected.count - 1)\u{E001}"
        }
        func protect(_ text: String, regex pattern: String, makeHTML: (String) -> String) -> String {
            guard let re = try? NSRegularExpression(pattern: pattern) else { return text }
            let ns = text as NSString
            let matches = re.matches(in: text, range: NSRange(location: 0, length: ns.length))
            var out = text
            for m in matches.reversed() {
                let piece = ns.substring(with: m.range(at: 1))
                let placeholder = token(makeHTML(piece))
                let range = Range(m.range, in: out)
                if let range { out.replaceSubrange(range, with: placeholder) }
            }
            return out
        }
        // Only generated, internal attachments become image placeholders. A
        // random ![](file://), ![](https://) or HTML img is NEVER loaded.
        var text = source
        text = protect(text, regex: #"`([^`\n]+)`"#) { "<code>\(esc($0))</code>" }
        if let imageRegex = try? NSRegularExpression(pattern:
            #"(?<!\\)!\[([^\]\n]{0,120})\]\((attachments/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.png)\)"#) {
            let ns = text as NSString
            let matches = imageRegex.matches(in: text, range: NSRange(location: 0, length: ns.length))
            for match in matches.reversed() {
                let alt = ns.substring(with: match.range(at: 1))
                let path = ns.substring(with: match.range(at: 2))
                let placeholder = token("<img data-mw-attachment='\(path)' alt='\(esc(alt))' class='memo-image'>")
                if let range = Range(match.range, in: text) { text.replaceSubrange(range, with: placeholder) }
            }
        }
        text = protect(text, regex: #"(?<!\\)\$([^$\n]+)\$"#) { expr in
            hasMath = true
            return "<span class='formula-inline' data-tex='\(esc(expr))'>\(esc(expr))</span>"
        }
        text = esc(text)
        text = replace(text, pattern: #"\*\*([^*\n]+)\*\*"#, template: "<strong>$1</strong>")
        text = replace(text, pattern: #"~~([^~\n]+)~~"#, template: "<del>$1</del>")
        // The ==mark== extension is deliberately opt-in via the advanced
        // insert menu; render it so the tool never inserts inert markup.
        text = replace(text, pattern: #"==([^=\n]+)=="#, template: "<mark>$1</mark>")
        text = replace(text, pattern: #"(?<!\*)\*([^*\n]+)\*(?!\*)"#, template: "<em>$1</em>")
        text = replace(text, pattern: #"\[([^\]\n]+)\]\(([^)\n]+)\)"#, template: "<span class='md-link'>$1</span>")
        text = replace(text, pattern: #"\[\^([^\]\n]+)\]"#, template: "<sup>[$1]</sup>")
        for idx in protected.indices { text = text.replacingOccurrences(of: "\u{E000}\(idx)\u{E001}", with: protected[idx]) }
        return text
    }

    // A single physical newline is a visual newline only in memo mode. Keep
    // source lines untouched and insert generated <br> elements AFTER HTML
    // escaping, so user-supplied HTML cannot run in the preview.
    private static func proseHTML(_ lines: [String], mode: MarkdownPreviewMode,
                                  hasMath: inout Bool) -> String {
        // Reserved markers are expanded only after inline HTML escaping. This
        // keeps emphasis spanning source lines intact without trusting raw HTML.
        let breakMarker = "\u{E100}"
        let indentMarker = "\u{E101}"
        var source = ""
        var previousHardBreak = false
        for (index, raw) in lines.enumerated() {
            if index > 0 { source += (mode == .memo || previousHardBreak) ? breakMarker : " " }
            let spacesAtEnd = raw.reversed().prefix(while: { $0 == " " }).count
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            let slashCount = trimmed.reversed().prefix(while: { $0 == "\\" }).count
            let slashBreak = slashCount % 2 == 1
            let visible = slashBreak ? String(trimmed.dropLast()) : trimmed
            previousHardBreak = slashBreak || spacesAtEnd >= 2
            if mode == .memo {
                // Only leading indentation is preserved visually. Internal
                // prose whitespace follows ordinary HTML collapsing rules.
                let leading = String(raw.prefix(while: { $0 == " " || $0 == "\t" }))
                let width = min(32, MarkdownListSyntax.indentation(leading))
                source += String(repeating: indentMarker, count: width) + visible
            } else {
                source += visible
            }
        }
        return inline(source, hasMath: &hasMath)
            .replacingOccurrences(of: breakMarker, with: "<br>")
            .replacingOccurrences(of: indentMarker, with: "&#160;")
    }

    private static func proseParagraphs(_ lines: [String], mode: MarkdownPreviewMode,
                                        hasMath: inout Bool) -> String {
        var segments: [[String]] = []
        var segment: [String] = []
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !segment.isEmpty { segments.append(segment); segment = [] }
            } else { segment.append(line) }
        }
        if !segment.isEmpty { segments.append(segment) }
        return segments.map { "<p>" + proseHTML($0, mode: mode, hasMath: &hasMath) + "</p>" }.joined()
    }

    private static func quoteContent(_ line: String) -> String {
        let normalized = line.trimmingCharacters(in: .whitespaces)
        let rest = normalized.dropFirst() // strip the quote marker
        return String(rest.first == " " ? rest.dropFirst() : rest[rest.startIndex...])
    }

    private static func beginsAnotherBlock(_ lines: [String], at index: Int,
                                           mode: MarkdownPreviewMode) -> Bool {
        let raw = lines[index]
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if MarkdownFenceSyntax.opening(raw) != nil || MarkdownListSyntax.item(raw) != nil ||
            trimmed.hasPrefix(">") || trimmed == "---" || trimmed == "***" ||
            trimmed == "$$" || trimmed.hasPrefix("$$") { return true }
        if mode == .standard && MarkdownListSyntax.indentation(raw) >= 4 { return true }
        if trimmed.range(of: #"^#{1,6}[ \t]+"#, options: .regularExpression) != nil { return true }
        if trimmed.range(of: #"^\[\^[^]]+\]:"#, options: .regularExpression) != nil { return true }
        if index + 1 < lines.count && trimmed.contains("|") &&
           lines[index + 1].range(of: #"^\s*\|?\s*:?-{3,}:?(\s*\|\s*:?-{3,}:?)+\s*\|?\s*$"#,
                                  options: .regularExpression) != nil { return true }
        return false
    }

    static func render(_ markdown: String, mode: MarkdownPreviewMode = .memo) -> Rendered {
        let source = markdown.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = source.components(separatedBy: "\n")
        var blocks: [String] = []
        var currentSourceLine = 1
        func addBlock(_ html: String) {
            // Source positions live in preview-only HTML; not in saved notes.
            blocks.append("<div class='md-block' data-md-line='\(currentSourceLine)'>\(html)</div>")
        }
        var math = false
        var i = 0
        while i < lines.count {
            currentSourceLine = i + 1
            let raw = lines[i]
            let trim = raw.trimmingCharacters(in: .whitespaces)
            if trim.isEmpty { i += 1; continue }
            if let fence = MarkdownFenceSyntax.opening(raw) {
                let lang = fence.language
                i += 1
                var contents: [String] = []
                while i < lines.count && !MarkdownFenceSyntax.closes(lines[i], fence: fence) {
                    contents.append(lines[i]); i += 1
                }
                if i < lines.count { i += 1 }
                let code = contents.joined(separator: "\n")
                switch lang {
                case "mermaid":
                    let fallback: String
                    if let svg = MermaidFlowchart.svg(code) {
                        fallback = "<div class='diagram'>\(svg)</div>"
                    } else {
                        let chartHint = WorkOSOfficialDiagramRuntime.chartType(for: code) == nil ?
                            "" : " XY 차트의 한글 x-axis 항목은 [\"1월\", \"2월\"]처럼 따옴표로 감싸세요."
                        fallback = "<div class='diagram-fallback'><p>Mermaid 공식 렌더러가 준비되지 않았거나 문법 오류가 있습니다.\(esc(chartHint)) 원문은 보존됩니다.</p><pre>\(esc(code))</pre></div>"
                    }
                    addBlock(WorkOSOfficialDiagramRuntime.wrapper(kind: "mermaid", source: code, fallback: fallback))
                case "markmap":
                    addBlock(WorkOSOfficialDiagramRuntime.wrapper(kind: "markmap", source: code, fallback: renderMarkmap(code)))
                case "vega-lite", "vegalite":
                    // Read-only legacy compatibility. No Vega/Chart.js dependency,
                    // authoring UI, network access, or saved-source rewriting.
                    addBlock(renderLegacyVegaBars(code))
                case "latex", "tex":
                    math = true
                    addBlock("<div class='formula' data-tex='\(esc(code))'><code>\(esc(code))</code></div>")
                default:
                    // Retain the language identifier as an escaped, inert
                    // label. Never execute or fetch code from a fenced block.
                    let langAttr = lang.isEmpty ? "" : " data-language='\(esc(lang))'"
                    addBlock("<pre\(langAttr)><code>\(esc(code))</code></pre>")
                }
                continue
            }
            // Only standard Markdown treats four-space source as implicit
            // code. In memo mode users can indent ordinary prose with Tab.
            if mode == .standard && MarkdownListSyntax.indentation(raw) >= 4 {
                var code: [String] = []
                while i < lines.count && MarkdownListSyntax.indentation(lines[i]) >= 4 {
                    let text = lines[i]
                    if text.hasPrefix("\t") { code.append(String(text.dropFirst())) }
                    else if text.hasPrefix("    ") { code.append(String(text.dropFirst(4))) }
                    else { code.append(text.trimmingCharacters(in: .whitespaces)) }
                    i += 1
                }
                addBlock("<pre><code>\(esc(code.joined(separator: "\n")))</code></pre>")
                continue
            }
            if trim == "$$" || trim.hasPrefix("$$") {
                var expr = ""
                if trim == "$$" {
                    i += 1
                    var chunks: [String] = []
                    while i < lines.count && lines[i].trimmingCharacters(in: .whitespaces) != "$$" {
                        chunks.append(lines[i]); i += 1
                    }
                    if i < lines.count { i += 1 }
                    expr = chunks.joined(separator: "\n")
                } else if trim.hasSuffix("$$") && trim.count > 4 {
                    expr = String(trim.dropFirst(2).dropLast(2)); i += 1
                } else {
                    addBlock("<pre>\(esc(raw))</pre>"); i += 1; continue
                }
                math = true
                addBlock("<div class='formula' data-tex='\(esc(expr))'><code>\(esc(expr))</code></div>")
                continue
            }
            if let heading = capture(#"^\s{0,3}(#{1,6})\s+(.+)$"#, in: raw),
               let headingText = capture(#"^\s{0,3}#{1,6}\s+(.+)$"#, in: raw) {
                let level = min(6, heading.count)
                addBlock("<h\(level)>\(inline(headingText, hasMath: &math))</h\(level)>")
                i += 1; continue
            }
            if i + 1 < lines.count, trim.contains("|"),
               lines[i+1].range(of: #"^\s*\|?\s*:?-{3,}:?(\s*\|\s*:?-{3,}:?)+\s*\|?\s*$"#, options: .regularExpression) != nil {
                var content = [lines[i], lines[i+1]]
                i += 2
                while i < lines.count && lines[i].contains("|") && !lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
                    content.append(lines[i]); i += 1
                }
                let table = content.joined(separator: "\n")
                if WorkOSTable.parse(table) != nil {
                    // GFM permits <br> for newlines within table cells; this
                    // is the ONLY raw HTML fragment permitted in table data.
                    addBlock(WorkOSTable.html(table).replacingOccurrences(of: "&lt;br&gt;", with: "<br>"))
                } else {
                    addBlock("<pre>\(esc(table))</pre>")
                }
                continue
            }
            if let kind = capture(#"^>\s*\[!([A-Za-z]+)\]"#, in: trim) {
                let normalized = kind.uppercased()
                let allowed = ["NOTE", "TIP", "IMPORTANT", "WARNING", "CAUTION"]
                if allowed.contains(normalized) {
                    let folded = capture(#"^>\s*\[![A-Za-z]+\]([+-])"#, in: trim)
                    let subtitle = capture(#"^>\s*\[![A-Za-z]+\][+-]?\s*(.*)$"#, in: trim) ?? ""
                    let summary = esc(normalized) + (subtitle.isEmpty ? "" : " · " + esc(subtitle))
                    i += 1
                    var contents: [String] = []
                    while i < lines.count && lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                        contents.append(quoteContent(lines[i]))
                        i += 1
                    }
                    let body = proseParagraphs(contents, mode: mode, hasMath: &math)
                    if let folded {
                        let open = folded == "+" ? " open" : ""
                        addBlock("<details class='callout'\(open)><summary>\(summary)</summary>\(body)</details>")
                    } else {
                        addBlock("<aside class='callout'><strong>\(summary)</strong>\(body)</aside>")
                    }
                    continue
                }
            }
            if let list = MarkdownListSyntax.render(lines: lines, start: i,
                                                    renderInline: { inline($0, hasMath: &math) }) {
                addBlock(list.html)
                i = list.next
                continue
            }
            if let footnoteID = capture(#"^\[\^([^]]+)\]:\s*(.*)$"#, in: trim),
               let text = capture(#"^\[\^[^]]+\]:\s*(.*)$"#, in: trim) {
                addBlock("<p class='footnote'><sup>[\(esc(footnoteID))]</sup> \(inline(text, hasMath: &math))</p>")
                i += 1; continue
            }
            if trim.hasPrefix("> ") || trim == ">" {
                var quotes: [String] = []
                while i < lines.count {
                    let quote = lines[i].trimmingCharacters(in: .whitespaces)
                    guard quote.hasPrefix("> ") || quote == ">" else { break }
                    quotes.append(quoteContent(lines[i]))
                    i += 1
                }
                addBlock("<blockquote>\(proseParagraphs(quotes, mode: mode, hasMath: &math))</blockquote>")
                continue
            }
            if trim == "---" || trim == "***" { addBlock("<hr>"); i += 1; continue }
            // Raw text stays raw. Soft newline semantics are a preview-only
            // setting; never insert backslashes or rewrite the saved Markdown.
            var text = [raw]
            i += 1
            while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
                if beginsAnotherBlock(lines, at: i, mode: mode) { break }
                text.append(lines[i]); i += 1
            }
            addBlock("<p>\(proseHTML(text, mode: mode, hasMath: &math))</p>")
        }
        return Rendered(html: blocks.joined(separator: "\n"), hasMath: math)
    }

    private static func renderMarkmap(_ source: String) -> String {
        // Read Markdown headings/lists into an immutable tree. SVG is a static,
        // offline preview; raw Markdown never leaves the editor or gets rewritten.
        struct Node { let depth: Int; let label: String; let parent: Int? }
        var nodes: [Node] = []
        var active: [Int: Int] = [:]
        var headingDepth = 0
        for line in source.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            var depth: Int
            var label: String
            if let hashes = capture(#"^(#{1,6})\s+"#, in: trimmed) {
                depth = hashes.count - 1
                headingDepth = depth
                label = String(trimmed.dropFirst(hashes.count)).trimmingCharacters(in: .whitespaces)
            } else if let bullet = capture(#"^(?:[-*+]|\d+[.)])\s+(.+)$"#, in: trimmed) {
                let leading = line.prefix(while: { $0 == " " || $0 == "\t" })
                let amount = leading.reduce(0) { $0 + ($1 == "\t" ? 4 : 1) }
                depth = headingDepth + 1 + min(5, amount / 2)
                label = bullet
            } else { continue }
            guard nodes.count < 80 else { break }
            depth = min(max(0, depth), 8)
            let parent = (0..<depth).reversed().compactMap { active[$0] }.first
            nodes.append(Node(depth: depth, label: label, parent: parent))
            active[depth] = nodes.count - 1
            for key in active.keys.filter({ $0 > depth }) { active.removeValue(forKey: key) }
        }
        guard !nodes.isEmpty else { return "<pre>\(esc(source))</pre>" }

        // Parents are vertically centered over their children. This creates a
        // real branching mindmap, not a list of indent-aligned rectangles.
        let count = nodes.count
        var children = Array(repeating: [Int](), count: count)
        var roots: [Int] = []
        for i in nodes.indices {
            if let parent = nodes[i].parent { children[parent].append(i) }
            else { roots.append(i) }
        }
        func wrapped(_ label: String, limit: Int = 16) -> [String] {
            let chars = Array(label)
            if chars.isEmpty { return [" "] }
            return stride(from: 0, to: chars.count, by: limit).map {
                String(chars[$0..<min(chars.count, $0 + limit)])
            }
        }
        let lines = nodes.map { wrapped($0.label) }
        let heights = lines.map { max(40, $0.count * 21 + 14) }
        var centers = Array(repeating: 0.0, count: count)
        var cursor = 18.0
        func place(_ index: Int) {
            if children[index].isEmpty {
                let height = Double(max(44, heights[index]))
                centers[index] = cursor + height / 2
                cursor += height + 17
            } else {
                for child in children[index] { place(child) }
                if let first = children[index].first, let last = children[index].last {
                    centers[index] = (centers[first] + centers[last]) / 2
                }
            }
        }
        for root in roots { place(root); cursor += 24 }

        // A different branch color is inherited by every descendant of that
        // first-level topic, giving a clear visual hierarchy at a glance.
        let colors = ["#4b7bd6", "#13a28e", "#d98b43", "#9c6ac6", "#d46886", "#69964b"]
        var branch = Array(repeating: 0, count: count)
        for i in nodes.indices {
            if let parent = nodes[i].parent {
                branch[i] = nodes[parent].parent == nil
                    ? (children[parent].firstIndex(of: i) ?? 0) : branch[parent]
            }
        }
        let columnStep = 228
        let nodeWidth = 182
        let maxDepth = nodes.map(\.depth).max() ?? 0
        let width = 28 + maxDepth * columnStep + nodeWidth + 22
        let height = max(112, Int(cursor.rounded(.up)) + 3)
        var shapes = ""
        // Draw links behind nodes. Cubic strokes terminate in a small dot,
        // rather than intersecting the leaf label like a Markdown outline.
        for (index, node) in nodes.enumerated() {
            guard let parent = node.parent else { continue }
            let hue = colors[branch[index] % colors.count]
            let fromX = 16 + nodes[parent].depth * columnStep + nodeWidth
            let toX = 16 + node.depth * columnStep - 7
            let mid = (fromX + toX) / 2
            let fromY = Int(centers[parent].rounded())
            let toY = Int(centers[index].rounded())
            let stroke = node.depth <= 1 ? "2.8" : "2"
            shapes += "<path d='M\(fromX) \(fromY) C\(mid) \(fromY) \(mid) \(toY) \(toX) \(toY)' stroke='\(hue)' stroke-width='\(stroke)' stroke-linecap='round' fill='none' opacity='0.85'/>"
            shapes += "<circle cx='\(toX)' cy='\(toY)' r='3.3' fill='\(hue)'/>"
        }
        for (index, node) in nodes.enumerated() {
            let x = 16 + node.depth * columnStep
            let centerY = Int(centers[index].rounded())
            let boxHeight = heights[index]
            let y = centerY - boxHeight / 2
            let hue = colors[branch[index] % colors.count]
            shapes += "<title>\(esc(node.label))</title>"
            if node.depth == 0 {
                shapes += "<rect x='\(x)' y='\(y)' width='\(nodeWidth)' height='\(boxHeight)' rx='13' fill='#273f69' stroke='#273f69'/>"
            } else if node.depth == 1 {
                shapes += "<rect x='\(x)' y='\(y)' width='\(nodeWidth)' height='\(boxHeight)' rx='10' fill='#f4f8fd' stroke='\(hue)' stroke-opacity='0.32'/>"
                shapes += "<rect x='\(x)' y='\(y + 5)' width='4' height='\(boxHeight - 10)' rx='2' fill='\(hue)'/>"
            } else {
                shapes += "<circle cx='\(x + 6)' cy='\(centerY)' r='4' fill='\(hue)'/>"
                shapes += "<path d='M\(x + 17) \(y + boxHeight - 5) H\(x + nodeWidth - 8)' stroke='\(hue)' stroke-width='1' opacity='0.28'/>"
            }
            for (row, content) in lines[index].enumerated() {
                let baseline = y + (boxHeight - lines[index].count * 21) / 2 + 16 + row * 21
                let tx = x + (node.depth < 2 ? 13 : 18)
                let fill = node.depth == 0 ? "#ffffff" : (node.depth == 1 ? "#263b56" : "#334155")
                let size = node.depth == 0 ? "17" : (node.depth == 1 ? "16" : "15")
                let weight = node.depth <= 1 ? "650" : "450"
                shapes += "<text x='\(tx)' y='\(baseline)' font-size='\(size)' font-weight='\(weight)' fill='\(fill)'>\(esc(content))</text>"
            }
        }
        return "<div class='diagram diagram-markmap'><svg viewBox='0 0 \(width) \(height)' style='display:block;width:100%;min-width:\(width)px;max-width:none;height:auto' role='img' aria-label='Markmap 기본 계층도' xmlns='http://www.w3.org/2000/svg'>\(shapes)</svg></div>"
    }


    // Compatibility with old notes only. This is NOT a Vega-Lite spec renderer:
    // just bounded inline JSON -> static SVG for simple nonnegative bar charts.
    // Zero work and zero external dependencies for notes without these fences.
    private static func renderLegacyVegaBars(_ source: String) -> String {
        func fallback(_ description: String) -> String {
            "<div class='diagram-fallback legacy-chart'><p>\(esc(description)) 신규 차트는 Mermaid를 사용하세요. 원문은 변경되지 않습니다.</p><pre><code>\(esc(source))</code></pre></div>"
        }
        // Do not parse oversized historical payloads or follow data URLs.
        guard source.utf8.count <= 64_000,
              let data = source.data(using: .utf8),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let values = (json["data"] as? [String: Any])?["values"] as? [[String: Any]],
              let encoding = json["encoding"] as? [String: Any],
              let xField = (encoding["x"] as? [String: Any])?["field"] as? String,
              let yField = (encoding["y"] as? [String: Any])?["field"] as? String else {
            return fallback("이전 Vega-Lite 문서는 간단한 인라인 막대그래프만 표시할 수 있습니다.")
        }
        let mark = (json["mark"] as? String) ?? ((json["mark"] as? [String: Any])?["type"] as? String ?? "")
        guard mark == "bar", !values.isEmpty, values.count <= 30 else {
            return fallback("이전 Vega-Lite 호환 기능은 최대 30개의 막대(bar)만 지원합니다.")
        }
        let points = values.compactMap { value -> (String, Double)? in
            guard let number = value[yField] as? NSNumber, let label = value[xField] else { return nil }
            let amount = number.doubleValue
            guard amount.isFinite, amount >= 0 else { return nil }
            return (String(describing: label), amount)
        }
        guard points.count == values.count else {
            return fallback("이전 Vega-Lite 값에 음수, 무한대 또는 올바르지 않은 항목이 있습니다.")
        }
        let maxValue = max(points.map(\.1).max() ?? 0, 1)
        let width = max(340, points.count * 62 + 40)
        let barWidth = Double(width - 55) / Double(points.count)
        var shapes = "<path d='M35 10 V230 H\(width-8)' stroke='#64748b' fill='none'/>"
        for (index, point) in points.enumerated() {
            let x = 42 + Double(index) * barWidth
            let height = max(1, 190 * point.1 / maxValue)
            let y = 230 - height
            shapes += "<rect x='\(x)' y='\(y)' width='\(max(8, barWidth-12))' height='\(height)' rx='2' fill='#4b87be'/>"
            shapes += "<text x='\(x+2)' y='\(y-6)' font-size='11' fill='#475569'>\(esc(String(format: "%.3g", point.1)))</text>"
            shapes += "<text x='\(x+2)' y='248' font-size='10' fill='#475569'>\(esc(String(point.0.prefix(9))))</text>"
        }
        return "<div class='diagram legacy-chart'><svg xmlns='http://www.w3.org/2000/svg' width='100%' viewBox='0 0 \(width) 270' role='img' aria-label='이전 Vega-Lite 기본 막대그래프'>\(shapes)</svg></div>"
    }
}


// One official Mermaid fence for each chart type, never Vega-Lite JSON.
// The same templates drive the toolbar and pure-Foundation regression tests.
enum MermaidChartTemplates {
    enum Kind: String, CaseIterable {
        case bar, line, mixed, pie, quadrant
        var title: String {
            switch self {
            case .bar: return "막대그래프"
            case .line: return "선그래프"
            case .mixed: return "막대 + 선"
            case .pie: return "원형 차트"
            case .quadrant: return "사분면 차트"
            }
        }
        var source: String {
            switch self {
            case .bar:
                return "```mermaid\nxychart-beta\n  title \"월별 업무량\"\n  x-axis [\"1월\", \"2월\", \"3월\", \"4월\"]\n  y-axis \"건수\" 0 --> 50\n  bar [12, 28, 21, 40]\n```\n"
            case .line:
                return "```mermaid\nxychart-beta\n  title \"월별 추이\"\n  x-axis [\"1월\", \"2월\", \"3월\", \"4월\"]\n  y-axis \"건수\" 0 --> 50\n  line [12, 28, 21, 40]\n```\n"
            case .mixed:
                return "```mermaid\nxychart-beta\n  title \"실적과 추이\"\n  x-axis [\"1월\", \"2월\", \"3월\", \"4월\"]\n  y-axis \"건수\" 0 --> 50\n  bar [12, 28, 21, 40]\n  line [10, 19, 29, 35]\n```\n"
            case .pie:
                return "```mermaid\npie showData\n  title 업무 구성\n  \"기획\" : 40\n  \"실행\" : 35\n  \"검토\" : 25\n```\n"
            case .quadrant:
                return "```mermaid\nquadrantChart\n  title 우선순위\n  x-axis 낮은 효과 --> 높은 효과\n  y-axis 낮은 비용 --> 높은 비용\n  quadrant-1 검토\n  quadrant-2 신중\n  quadrant-3 보류\n  quadrant-4 빠른 실행\n  선택 A: [0.7, 0.2]\n```\n"
            }
        }
        var focusToken: String { self == .pie ? "기획" : (self == .quadrant ? "선택 A" : "1월") }
    }
    static func insertion(for kind: Kind) -> MarkdownInsertRequest {
        let source = kind.source
        let ns = source as NSString
        let match = ns.range(of: kind.focusToken)
        let caretBack = match.location == NSNotFound ? 0 : ns.length - match.location
        return MarkdownInsertRequest(source: source, caretBack: caretBack)
    }
}


// First row counts as the header. User chooses total visible rows/columns.
enum MarkdownTableGridCore {
    static func insertion(columns: Int, rows: Int) -> MarkdownInsertRequest {
        let c = max(1, min(8, columns))
        let r = max(2, min(8, rows))
        let header = "| " + (1...c).map { "열 \($0)" }.joined(separator: " | ") + " |"
        let divider = "| " + Array(repeating: "---", count: c).joined(separator: " | ") + " |"
        let cells = "| " + Array(repeating: "내용", count: c).joined(separator: " | ") + " |"
        let source = ([header, divider] + Array(repeating: cells, count: r - 1)).joined(separator: "\n") + "\n"
        let ns = source as NSString
        let match = ns.range(of: "내용")
        return MarkdownInsertRequest(source: source, caretBack: match.location == NSNotFound ? 0 : ns.length - match.location)
    }
}

// All three advanced diagrams use the existing offline Mermaid 12.2 engine.
// The panel remains a single reusable Markdown source editor.
enum MermaidDiagramTemplates {
    enum Kind: String, CaseIterable {
        case gantt, timeline, sequence, classDiagram, stateDiagram, erDiagram, gitGraph, journey
        var title: String {
            switch self {
            case .gantt: return "일정 · Gantt"
            case .timeline: return "이력 · Timeline"
            case .sequence: return "대화·처리 · Sequence"
            case .classDiagram: return "클래스 구조 · Class"
            case .stateDiagram: return "상태 전이 · State"
            case .erDiagram: return "데이터 관계 · ER"
            case .gitGraph: return "버전 이력 · Git"
            case .journey: return "사용자 여정 · Journey"
            }
        }
    }
    static func insertion(for kind: Kind) -> MarkdownInsertRequest {
        let date = String(ISO8601DateFormatter().string(from: Date()).prefix(10))
        let source: String
        let focus: String
        switch kind {
        case .gantt:
            source = "```mermaid\ngantt\n  title 업무 일정\n  dateFormat YYYY-MM-DD\n  section 준비\n  조사 :task1, \(date), 3d\n  검토 :task2, after task1, 2d\n```\n"
            focus = "업무 일정"
        case .timeline:
            source = "```mermaid\ntimeline\n  title 진행 이력\n  오늘 : 현황 확인\n       : 개선안 작성\n  내일 : 후속 점검\n```\n"
            focus = "진행 이력"
        case .sequence:
            source = "```mermaid\nsequenceDiagram\n  participant A as 요청자\n  participant B as 담당자\n  A->>B: 검토 요청\n  B-->>A: 결과 공유\n```\n"
            focus = "요청자"
        case .classDiagram:
            source = "```mermaid\nclassDiagram\n  class Note {\n    +String title\n    +save()\n  }\n  Notebook \"1\" --> \"*\" Note : contains\n```\n"
            focus = "Note"
        case .stateDiagram:
            source = "```mermaid\nstateDiagram-v2\n  [*] --> Draft\n  Draft --> Review: 제출\n  Review --> Done: 승인\n  Done --> [*]\n```\n"
            focus = "Draft"
        case .erDiagram:
            source = "```mermaid\nerDiagram\n  NOTEBOOK ||--o{ NOTE : contains\n  NOTEBOOK {\n    string id\n    string name\n  }\n  NOTE {\n    string id\n    string title\n  }\n```\n"
            focus = "NOTEBOOK"
        case .gitGraph:
            source = "```mermaid\ngitGraph\n  commit id: \"초기 기록\"\n  branch feature\n  checkout feature\n  commit id: \"수정\"\n  checkout main\n  merge feature\n```\n"
            focus = "초기 기록"
        case .journey:
            source = "```mermaid\njourney\n  title 기록 경험\n  section 작성\n    메모 입력: 5: 사용자\n    미리보기: 4: 사용자\n```\n"
            focus = "기록 경험"
        }
        let ns = source as NSString
        let match = ns.range(of: focus)
        return MarkdownInsertRequest(source: source,
                                     caretBack: match.location == NSNotFound ? 0 : ns.length - match.location)
    }
}
