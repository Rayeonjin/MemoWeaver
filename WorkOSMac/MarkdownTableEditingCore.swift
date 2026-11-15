import Foundation

/// Source-preserving table operations. All replacement offsets use UTF-16.
enum MarkdownTableEditingCore {
    enum Action: Int, CaseIterable {
        case insertRow, deleteRow, insertColumn, deleteColumn, align
        var title: String {
            switch self {
            case .insertRow: return "아래에 행 추가"
            case .deleteRow: return "현재 행 삭제"
            case .insertColumn: return "오른쪽에 열 추가"
            case .deleteColumn: return "현재 열 삭제"
            case .align: return "표 원문 간격 정리"
            }
        }
    }
    struct Change { let range: NSRange; let source: String }
    private struct Row { var cells: [String]; let separators: [Int] }
    private static func row(_ text: String) -> Row? {
        let chars = Array(text.utf16)
        var pipes: [Int] = [], ticks = 0, i = 0
        while i < chars.count {
            if chars[i] == 92 { i += 2; continue }
            if chars[i] == 96 {
                var end = i
                while end < chars.count && chars[end] == 96 { end += 1 }
                if ticks == 0 { ticks = end - i } else if ticks == end - i { ticks = 0 }
                i = end; continue
            }
            if chars[i] == 124 && ticks == 0 { pipes.append(i) }
            i += 1
        }
        guard !pipes.isEmpty, ticks == 0 else { return nil }
        let ns = text as NSString
        var bounds = [-1] + pipes + [ns.length]
        if ns.substring(to: pipes[0]).trimmingCharacters(in: .whitespaces).isEmpty { bounds.removeFirst() }
        if ns.substring(from: pipes.last! + 1).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { bounds.removeLast() }
        let cells = zip(bounds, bounds.dropFirst()).map {
            ns.substring(with: NSRange(location: $0 + 1, length: $1 - $0 - 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard (2...24).contains(cells.count) else { return nil }
        return Row(cells: cells, separators: Array(bounds.dropFirst().dropLast()))
    }
    static func change(in source: String, selection: NSRange, action: Action) -> Change? {
        let ns = source as NSString
        guard ns.length <= 2_000_000, selection.location >= 0, selection.location <= ns.length,
              selection.length >= 0, selection.length <= ns.length - selection.location else { return nil }
        let lines = ns.components(separatedBy: "\n")
        var offsets: [Int] = [], offset = 0
        for line in lines { offsets.append(offset); offset += (line as NSString).length + 1 }
        guard let anchor = offsets.indices.last(where: { offsets[$0] <= selection.location }) else { return nil }
        for start in stride(from: anchor, through: max(0, anchor - 301), by: -1) {
            guard start + 1 < lines.count, let header = row(lines[start]), let divider = row(lines[start + 1]),
                  divider.cells.count == header.cells.count,
                  divider.cells.allSatisfy({ $0.range(of: #"^:?-{3,}:?$"#, options: .regularExpression) != nil }) else { continue }
            guard MarkdownContextCore.context(in: source, utf16Offset: offsets[start]) == .normal else { continue }
            var rows = [header, divider], end = start + 2
            while end < lines.count, let next = row(lines[end]), next.cells.count == header.cells.count {
                rows.append(next); end += 1
                if rows.count > 302 { return nil }
            }
            let last = offsets[end - 1] + (lines[end - 1] as NSString).length
            guard anchor < end, NSMaxRange(selection) <= last else { continue }
            let r = anchor - start
            let c = min(header.cells.count - 1, rows[r].separators.filter { $0 < selection.location - offsets[anchor] }.count)
            var cells = rows.map(\.cells)
            switch action {
            case .insertRow:
                guard rows.count < 302 else { return nil }
                cells.insert(Array(repeating: "", count: header.cells.count), at: max(2, r + 1))
            case .deleteRow:
                guard r >= 2 else { return nil }
                cells.remove(at: r)
            case .insertColumn:
                guard header.cells.count < 24 else { return nil }
                for i in cells.indices { cells[i].insert(i == 1 ? "---" : "", at: c + 1) }
            case .deleteColumn:
                guard header.cells.count > 2 else { return nil }
                for i in cells.indices { cells[i].remove(at: c) }
            case .align: break
            }
            let widths = cells[0].indices.map { col in max(3, cells.map { $0[col].count }.max() ?? 3) }
            let rendered = cells.enumerated().map { index, values -> String in
                let parts = values.enumerated().map { col, value -> String in
                    if index == 1 {
                        let left = value.hasPrefix(":") ? ":" : ""
                        let right = value.hasSuffix(":") ? ":" : ""
                        return left + String(repeating: "-", count: max(3, widths[col] - left.count - right.count)) + right
                    }
                    return value + String(repeating: " ", count: max(0, widths[col] - value.count))
                }
                return "| " + parts.joined(separator: " | ") + " |"
            }
            let newline = lines[start].hasSuffix("\r") ? "\r\n" : "\n"
            let trailingCR = lines[end - 1].hasSuffix("\r") ? "\r" : ""
            return Change(range: NSRange(location: offsets[start], length: last - offsets[start]),
                          source: rendered.joined(separator: newline) + trailingCR)
        }
        return nil
    }
}
