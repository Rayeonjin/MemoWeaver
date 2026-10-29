import Foundation

// These are additive fields in the legacy JSON note record. Old WorkOS notes
// remain readable without any SQLite schema migration.
struct WorkBlock: Identifiable, Codable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        case table, equation, mermaid
        var title: String {
            switch self {
            case .table: return "표"
            case .equation: return "LaTeX 수식"
            case .mermaid: return "Mermaid 흐름도"
            }
        }
    }
    var id: String
    var kind: Kind
    var source: String

    static func make(_ kind: Kind) -> WorkBlock {
        let content: String
        switch kind {
        case .table:
            content = "| 항목 | 내용 |\n| --- | --- |\n| 예시 | 설명을 입력하세요 |"
        case .equation:
            content = #"E = mc^2"#
        case .mermaid:
            content = "flowchart TD\n  A[시작] --> B{확인}\n  B -->|예| C[완료]\n  B -->|아니요| D[다시 검토]"
        }
        return WorkBlock(id: UUID().uuidString, kind: kind, source: content)
    }

    static func read(_ raw: [[String: Any]]) -> [WorkBlock] {
        raw.compactMap { d in
            guard let kind = Kind(rawValue: WorkOSJSON.string(d, "kind")) else { return nil }
            return WorkBlock(id: WorkOSJSON.string(d, "id", default: UUID().uuidString),
                             kind: kind, source: WorkOSJSON.string(d, "source"))
        }
    }

    static func encode(_ blocks: [WorkBlock]) -> [[String: Any]] {
        blocks.map { ["id": $0.id, "kind": $0.kind.rawValue, "source": $0.source] }
    }
}

enum WorkOSTable {
    // Simple CommonMark/GFM tables. Cells allow escaped literal pipes (\|).
    static func split(_ line: String) -> [String] {
        var text = line.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("|") { text.removeFirst() }
        if text.hasSuffix("|") { text.removeLast() }
        var cells: [String] = [], token = "", escaped = false
        for c in text {
            if escaped {
                if c != "|" && c != "\\" { token.append("\\") }
                token.append(c)
                escaped = false
                continue
            }
            if c == "\\" { escaped = true; continue }
            if c == "|" { cells.append(token.trimmingCharacters(in: .whitespaces)); token = "" }
            else { token.append(c) }
        }
        if escaped { token.append("\\") }
        cells.append(token.trimmingCharacters(in: .whitespaces))
        return cells
    }
    static func parse(_ markdown: String) -> [[String]]? {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard lines.count >= 2 else { return nil }
        let first = split(lines[0]), dividers = split(lines[1])
        guard first.count > 0, first.count <= 12, first.count == dividers.count,
              dividers.allSatisfy({ $0.range(of: #"^:?-{3,}:?$"#, options: .regularExpression) != nil }) else { return nil }
        var rows = [first]
        for line in lines.dropFirst(2).prefix(250) {
            let cells = split(line)
            guard cells.count == first.count else { return nil }
            rows.append(cells)
        }
        return rows
    }
    static func markdown(_ rows: [[String]]) -> String {
        guard let headings = rows.first, !headings.isEmpty else { return "" }
        let columns = headings.count
        func row(_ cells: [String]) -> String {
            "| " + (0..<columns).map { idx in
                (idx < cells.count ? cells[idx] : "")
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "|", with: "\\|")
                    .replacingOccurrences(of: "\n", with: " ")
            }.joined(separator: " | ") + " |"
        }
        return ([row(headings), row(Array(repeating: "---", count: columns))] + rows.dropFirst().map(row)).joined(separator: "\n")
    }
    static func html(_ markdown: String) -> String {
        guard let rows = parse(markdown), let heading = rows.first else {
            return "<pre>\(escapeHTML(markdown))</pre>"
        }
        let head = "<thead><tr>" + heading.map { "<th>\(escapeHTML($0))</th>" }.joined() + "</tr></thead>"
        let body = rows.dropFirst().map { row in
            "<tr>" + row.map { "<td>\(escapeHTML($0))</td>" }.joined() + "</tr>"
        }.joined()
        return "<table class='workos-table'>\(head)<tbody>\(body)</tbody></table>"
    }
}

// A bounded, offline SVG renderer for common Mermaid flowcharts.
// It is deliberately NOT a full Mermaid engine: sequence/gantt/advanced styles
// keep their original source and show a clear fallback in the preview.
// No remote scripts, HTML label execution or source-data mutations.
enum MermaidFlowchart {
    struct Node {
        var key: String
        var label: String
        var shape: String
    }
    struct Edge {
        var from: String
        var to: String
        var label: String
        var stroke: String
    }
    private static let header = try! NSRegularExpression(
        pattern: #"(?i)^\s*(?:flowchart|graph)\s+(TD|TB|LR|RL|BT)(?:\s+(.+))?\s*$"#)
    // Standard Mermaid node shapes commonly used with flowchart templates.
    // Keep all labels as *text*, not HTML; SVG entities are escaped below.
    private static let nodeToken = try! NSRegularExpression(pattern:
        #"^\s*([\p{L}\p{N}_]+(?:-[\p{L}\p{N}_]+)*)(?:\s*(?:\[([^\]]*)\]|\{([^}]*)\}|\(\(([^)]*)\)\)|\(\[([^\]]*)\]\)|\(([^)]*)\)))?(?:::[\p{L}\p{N}_-]+)?"#)
    private static let arrowToken = try! NSRegularExpression(pattern:
        #"^\s*(?:--\s+(.+?)\s+-->|-\.\s+(.+?)\s+\.->|(-->|---|-\.->|==>|--o|--x)(?:\s*\|([^|]*)\|)?)"#)

    private static func capture(_ match: NSTextCheckingResult, _ text: String, _ index: Int) -> String {
        guard index < match.numberOfRanges else { return "" }
        let range = match.range(at: index)
        return range.location == NSNotFound ? "" : (text as NSString).substring(with: range)
    }
    private static func match(_ regex: NSRegularExpression, _ text: String) -> NSTextCheckingResult? {
        regex.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length))
    }
    private static func rest(_ text: String, after range: NSRange) -> String {
        let ns = text as NSString
        return ns.substring(from: min(ns.length, NSMaxRange(range)))
    }
    private static func statements(_ source: String) -> [String] {
        // Semicolons separate Mermaid statements, but not quoted/node labels.
        var pieces: [String] = []
        var buffer = ""
        var quoted: Character? = nil
        var brackets = 0
        for char in source {
            if let quote = quoted {
                if char == quote { quoted = nil }
                buffer.append(char)
                continue
            }
            if char == "\"" || char == "'" { quoted = char }
            if char == "[" || char == "{" || char == "(" { brackets += 1 }
            if char == "]" || char == "}" || char == ")" { brackets = max(0, brackets - 1) }
            if (char == ";" && brackets == 0) || char == "\n" || char == "\r" {
                let item = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
                if !item.isEmpty { pieces.append(item) }
                buffer = ""
            } else { buffer.append(char) }
        }
        let item = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !item.isEmpty { pieces.append(item) }
        return pieces
    }
    private static func parsedNode(_ input: String) -> (node: Node, remainder: String)? {
        guard let found = match(nodeToken, input), found.range.location == 0 else { return nil }
        let id = capture(found, input, 1)
        guard !id.isEmpty else { return nil }
        let labels = (2...6).map { capture(found, input, $0) }
        let selected = labels.first(where: { !$0.isEmpty }) ?? id
        let shape = !labels[1].isEmpty ? "diamond" : (!labels[2].isEmpty ? "circle" : "rect")
        let cleaned = selected.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        return (Node(key: id, label: cleaned, shape: shape), rest(input, after: found.range))
    }
    private static func parsedArrow(_ input: String) -> (label: String, stroke: String, remainder: String)? {
        guard let found = match(arrowToken, input), found.range.location == 0 else { return nil }
        let candidates = [1, 2, 4].map { capture(found, input, $0) }
        let arrow = capture(found, input, 3)
        let style: String
        if !capture(found, input, 2).isEmpty || arrow == "-.->" { style = "dotted" }
        else if arrow == "==>" { style = "bold" }
        else if arrow == "---" { style = "plain" }
        else if arrow == "--o" { style = "circle" }
        else if arrow == "--x" { style = "cross" }
        else { style = "solid" }
        return (candidates.first(where: { !$0.isEmpty }) ?? "", style, rest(input, after: found.range))
    }

    static func svg(_ source: String) -> String? {
        guard (source as NSString).length < 70_000 else { return nil }
        var parts = statements(source).filter { !$0.hasPrefix("%%") }
        guard !parts.isEmpty, let head = match(header, parts[0]) else { return nil }
        let direction = capture(head, parts[0], 1).uppercased()
        let sameLine = capture(head, parts[0], 2).trimmingCharacters(in: .whitespaces)
        parts.removeFirst()
        if !sameLine.isEmpty { parts.insert(sameLine, at: 0) }
        var nodes: [Node] = [], edges: [Edge] = []
        var visuallyIgnored = false
        func register(_ node: Node) {
            if let index = nodes.firstIndex(where: { $0.key == node.key }) {
                // A subsequent bare mention must not overwrite a declaration.
                if node.label != node.key { nodes[index].label = node.label; nodes[index].shape = node.shape }
            } else { nodes.append(node) }
        }
        var groupDepth = 0
        for part in parts {
            let statement = part.trimmingCharacters(in: .whitespaces)
            if statement.hasPrefix("%%") { continue }
            // Subgraph membership/style directives do not change source or
            // suppress valid edges. Group boxes and CSS styles are unsupported.
            if statement.range(of: #"(?i)^subgraph\b"#, options: .regularExpression) != nil {
                groupDepth += 1; visuallyIgnored = true; continue
            }
            if statement.lowercased() == "end" && groupDepth > 0 {
                groupDepth -= 1; continue
            }
            if statement.range(of: #"(?i)^(classDef|class|style|linkStyle|click|direction)\b"#,
                               options: .regularExpression) != nil {
                visuallyIgnored = true; continue
            }
            guard let first = parsedNode(statement) else { return nil }
            register(first.node)
            var previous = first.node
            var remaining = first.remainder
            var hops = 0
            while !remaining.trimmingCharacters(in: .whitespaces).isEmpty {
                guard let arrow = parsedArrow(remaining), let next = parsedNode(arrow.remainder) else { return nil }
                register(next.node)
                edges.append(Edge(from: previous.key, to: next.node.key, label: arrow.label, stroke: arrow.stroke))
                previous = next.node
                remaining = next.remainder
                hops += 1
                guard hops < 120 else { return nil }
            }
            guard nodes.count <= 80 && edges.count <= 120 else { return nil }
        }
        guard !nodes.isEmpty else { return nil }
        let horizontal = direction == "LR" || direction == "RL"
        let reversed = direction == "RL" || direction == "BT"
        let indexes = Dictionary(uniqueKeysWithValues: nodes.enumerated().map { ($0.element.key, $0.offset) })
        // The subset parser must not collapse a whole cyclic component into
        // depth zero. Use first-seen forward edges for layering; feedback
        // edges stay visible but do not invalidate the primary flow direction.
        var level = Array(repeating: 0, count: nodes.count)
        var indegree = Array(repeating: 0, count: nodes.count)
        for e in edges {
            if let a = indexes[e.from], let b = indexes[e.to], a < b { indegree[b] += 1 }
        }
        var queue = nodes.indices.filter { indegree[$0] == 0 }
        var processed = 0
        while processed < queue.count {
            let a = queue[processed]; processed += 1
            for e in edges where indexes[e.from] == a {
                guard let b = indexes[e.to], a < b else { continue }
                level[b] = max(level[b], min(24, level[a] + 1))
                indegree[b] -= 1
                if indegree[b] == 0 { queue.append(b) }
            }
        }
        // Cycles are valid Mermaid flowcharts. Keep cyclic nodes in their
        // existing layer instead of rejecting the entire diagram.
        let maxDepth = level.max() ?? 0
        let maxPerLevel = (0...maxDepth).map { d in level.filter { $0 == d }.count }.max() ?? 1
        let width = horizontal ? max(470, 225 + 205 * maxDepth) : max(480, maxPerLevel * 198 + 105)
        let height = horizontal ? max(205, maxPerLevel * 118 + 70) : max(205, 145 + 137 * maxDepth)
        var centers: [(Int, Int)] = Array(repeating: (0, 0), count: nodes.count)
        for depth in 0...maxDepth {
            let members = nodes.indices.filter { level[$0] == depth }
            for (order, index) in members.enumerated() {
                if horizontal {
                    let raw = 105 + depth * 205
                    centers[index] = (reversed ? width - raw : raw,
                                      height / 2 + order * 118 - (members.count - 1) * 59)
                } else {
                    let raw = 75 + depth * 137
                    centers[index] = (width / 2 + order * 198 - (members.count - 1) * 99,
                                      reversed ? height - raw : raw)
                }
            }
        }
        var out = "<svg xmlns='http://www.w3.org/2000/svg' role='img' aria-label='Mermaid flowchart' viewBox='0 0 \(width) \(height)' style='display:block;width:\(width)px;height:\(height)px;max-width:none;background:#fff;border-radius:8px'>"
        // The 2026 Mermaid engine is not bundled: this is a bounded offline
        // flowchart subset. Use smooth Bézier paths and subtle markers instead
        // of hard straight lines that collide with the node boundary.
        out += "<defs>"
        out += "<marker id='workos-mermaid-arrow' markerWidth='10' markerHeight='10' refX='8' refY='5' orient='auto' markerUnits='userSpaceOnUse'><path d='M1 1.5 L8 5 L1 8.5 Z' fill='#64748b'/></marker>"
        out += "<marker id='workos-mermaid-circle' markerWidth='10' markerHeight='10' refX='5' refY='5' orient='auto' markerUnits='userSpaceOnUse'><circle cx='5' cy='5' r='3.5' fill='#fff' stroke='#64748b' stroke-width='1.8'/></marker>"
        out += "<marker id='workos-mermaid-cross' markerWidth='10' markerHeight='10' refX='5' refY='5' orient='auto' markerUnits='userSpaceOnUse'><path d='M2 2 L8 8 M8 2 L2 8' stroke='#64748b' stroke-width='2' stroke-linecap='round'/></marker>"
        out += "</defs>"
        for e in edges {
            guard let a = indexes[e.from], let b = indexes[e.to] else { continue }
            let (ax, ay) = centers[a], (bx, by) = centers[b]
            let sign = horizontal ? (bx >= ax ? 1 : -1) : (by >= ay ? 1 : -1)
            func extent(_ shape: String, horizontal: Bool) -> Int {
                if horizontal { return shape == "diamond" ? 78 : (shape == "circle" ? 76 : 78) }
                return shape == "diamond" ? 38 : (shape == "circle" ? 32 : 31)
            }
            let departing = extent(nodes[a].shape, horizontal: horizontal)
            let arriving = extent(nodes[b].shape, horizontal: horizontal)
            let sx = ax + (horizontal ? sign * departing : 0)
            let sy = ay + (horizontal ? 0 : sign * departing)
            let ex = bx - (horizontal ? sign * (arriving + 7) : 0)
            let ey = by - (horizontal ? 0 : sign * (arriving + 7))
            let span = horizontal ? abs(ex - sx) : abs(ey - sy)
            let bend = max(21, Int(Double(span) * 0.45))
            let c1x = sx + (horizontal ? sign * bend : 0)
            let c1y = sy + (horizontal ? 0 : sign * bend)
            let c2x = ex - (horizontal ? sign * bend : 0)
            let c2y = ey - (horizontal ? 0 : sign * bend)
            let width = e.stroke == "bold" ? "3" : "1.8"
            let dash = e.stroke == "dotted" ? " stroke-dasharray='5 5'" : ""
            let marker = e.stroke == "plain" ? "" :
                (e.stroke == "circle" ? "workos-mermaid-circle" :
                 (e.stroke == "cross" ? "workos-mermaid-cross" : "workos-mermaid-arrow"))
            let end = marker.isEmpty ? "" : " marker-end='url(#\(marker))'"
            out += "<path d='M\(sx) \(sy) C\(c1x) \(c1y) \(c2x) \(c2y) \(ex) \(ey)' stroke='#64748b' stroke-width='\(width)' fill='none' stroke-linecap='round' stroke-linejoin='round'\(dash)\(end)/>"
            if !e.label.isEmpty {
                let mx = (sx + ex) / 2
                let my = (sy + ey) / 2 - 8
                let labelWidth = min(184, max(34, e.label.count * 12 + 18))
                out += "<rect x='\(mx - labelWidth / 2)' y='\(my - 16)' width='\(labelWidth)' height='22' rx='6' fill='#ffffff' fill-opacity='0.94'/>"
                out += "<text x='\(mx)' y='\(my)' text-anchor='middle' font-size='13' fill='#475569'>\(escapeHTML(e.label))</text>"
            }
        }
        for (i, node) in nodes.enumerated() {
            let (x, y) = centers[i]
            switch node.shape {
            case "diamond": out += "<path d='M\(x) \(y - 38) L\(x + 78) \(y) L\(x) \(y + 38) L\(x - 78) \(y) Z' fill='#ecfeff' stroke='#0e7490' stroke-width='1.8'/>"
            case "circle": out += "<ellipse cx='\(x)' cy='\(y)' rx='76' ry='32' fill='#f0fdf4' stroke='#15803d' stroke-width='1.8'/>"
            default: out += "<rect x='\(x - 78)' y='\(y - 31)' width='156' height='62' rx='9' fill='#eff6ff' stroke='#2563eb' stroke-width='1.8'/>"
            }
            let label = String(node.label.prefix(72))
            let text = label.count <= 15 ? [label] : [String(label.prefix(15)), String(label.dropFirst(15).prefix(15))]
            out += "<title>\(escapeHTML(node.label))</title>"
            for (row, content) in text.enumerated() {
                let baseline = y + (text.count == 1 ? 5 : -3 + row * 18)
                out += "<text x='\(x)' y='\(baseline)' text-anchor='middle' fill='#0f172a' font-size='14' font-family='-apple-system, sans-serif'>\(escapeHTML(content))</text>"
            }
        }
        out += "</svg>"
        if visuallyIgnored {
            out += "<p class='diagram-note'>하위 그룹·스타일 선언은 이 간단 미리보기에서 레이아웃에 반영되지 않습니다.</p>"
        }
        return out
    }
}
