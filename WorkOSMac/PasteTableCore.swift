import Foundation

// Pure Foundation helpers: no database access and no modification of stored notes.
// NSTextView / NSTextStorage positions are UTF-16 offsets (NSRange).
// A row/column-addressed cell makes empty and merged cells explicit in TSV.
// Pure Foundation so this conversion can be regression-tested without AppKit.
struct WorkOSPlainTableCell {
    let row: Int
    let column: Int
    let rowSpan: Int
    let columnSpan: Int
    var text: String
}

enum WorkOSPasteTable {
    static func tableText(cells: [WorkOSPlainTableCell], columnCount: Int) -> String? {
        guard !cells.isEmpty, columnCount >= 0, columnCount <= 256 else { return nil }
        var maxRow = 0
        var maxColumn = columnCount
        for cell in cells {
            guard cell.row >= 0, cell.column >= 0,
                  cell.rowSpan > 0, cell.columnSpan > 0,
                  cell.row <= 10_000 - cell.rowSpan,
                  cell.column <= 256 - cell.columnSpan else { return nil }
            maxRow = max(maxRow, cell.row + cell.rowSpan)
            maxColumn = max(maxColumn, cell.column + cell.columnSpan)
        }
        guard maxRow > 0, maxColumn <= 256 else { return nil }
        var grid = Array(repeating: Array(repeating: "", count: maxColumn), count: maxRow)
        var occupied = Array(repeating: Array(repeating: false, count: maxColumn), count: maxRow)
        for cell in cells {
            for row in cell.row..<(cell.row + cell.rowSpan) {
                for column in cell.column..<(cell.column + cell.columnSpan) {
                    guard !occupied[row][column] else { return nil }
                    occupied[row][column] = true
                }
            }
            grid[cell.row][cell.column] = quoteTSV(cell.text)
        }
        return grid.map { $0.joined(separator: "\t") }.joined(separator: "\n")
    }

    static func tabDelimitedText(from clipboard: String) -> String? {
        let normalized = normalizeNewlines(clipboard)
        guard normalized.contains("\t"),
              normalized.contains(where: { !$0.isWhitespace }) else { return nil }
        return normalized
    }

    // Excel may publish TSV, plain text, HTML, or a combination of these.
    // Prefer its lossless TSV. HTML tables also cover single-column selections
    // and clipboard producers that do not expose tab-separated plain text.
    static func preferredText(plain: String?, tabular: String?, html: String?) -> String? {
        if let tabular, let text = tabDelimitedText(from: tabular) { return text }
        if let plain, let text = tabDelimitedText(from: plain) { return text }
        if let html, let text = htmlTableText(from: html) { return text }
        return nil
    }

    // Deliberately small HTML-table reader, not a web renderer. Parses a copied
    // table's data cells into TSV without executing HTML or loading any assets.
    // Reserves empty cells for colspan / rowspan when present.
    static func htmlTableText(from html: String) -> String? {
        guard let table = firstCapture(#"(?is)<table\b[^>]*>(.*?)</table\s*>"#, in: html, group: 1)
        else { return nil }
        let rows = matches(#"(?is)<tr\b[^>]*>(.*?)</tr\s*>"#, in: table)
        guard !rows.isEmpty else { return nil }
        var parsed: [[String]] = []
        var spans: [Int: Int] = [:] // column -> further rows occupied by merged cell
        var maximumColumns = 0

        for row in rows.prefix(10_000) {
            guard let inner = substring(row, group: 1, in: table) else { continue }
            let cells = matches(#"(?is)<(td|th)\b([^>]*)>(.*?)</\1\s*>"#, in: inner)
            guard !cells.isEmpty else { continue }
            var columns: [String] = []
            var column = 0

            func fillMergedColumns() {
                while let count = spans[column], count > 0, column < 256 {
                    columns.append("")
                    if count == 1 { spans.removeValue(forKey: column) }
                    else { spans[column] = count - 1 }
                    column += 1
                }
            }

            for cell in cells {
                fillMergedColumns()
                guard column < 256 else { break }
                let attributes = substring(cell, group: 2, in: inner) ?? ""
                let value = cleanCell(substring(cell, group: 3, in: inner) ?? "")
                let colspan = min(256 - column, spanValue("colspan", in: attributes))
                let rowspan = spanValue("rowspan", in: attributes)
                for offset in 0..<colspan {
                    columns.append(offset == 0 ? quoteTSV(value) : "")
                    if rowspan > 1 { spans[column + offset] = rowspan - 1 }
                }
                column += colspan
            }
            // Preserve cells that were vertically merged in earlier rows.
            let priorMaximum = max(maximumColumns, (spans.keys.max() ?? -1) + 1)
            while column < min(priorMaximum, 256) {
                if let count = spans[column], count > 0 {
                    columns.append("")
                    if count == 1 { spans.removeValue(forKey: column) }
                    else { spans[column] = count - 1 }
                } else {
                    columns.append("")
                }
                column += 1
            }
            maximumColumns = max(maximumColumns, columns.count)
            parsed.append(columns)
        }
        guard !parsed.isEmpty, maximumColumns > 0,
              parsed.contains(where: { row in row.contains(where: { !$0.isEmpty }) }) else { return nil }
        return parsed.map { row in
            (row + Array(repeating: "", count: max(0, maximumColumns - row.count))).joined(separator: "\t")
        }.joined(separator: "\n")
    }

    static func insertedRange(selection: NSRange, previousLength: Int,
                              currentLength: Int) -> NSRange? {
        guard selection.location != NSNotFound,
              selection.location >= 0,
              selection.length >= 0,
              previousLength >= 0,
              currentLength >= 0,
              selection.location <= previousLength,
              selection.length <= previousLength - selection.location else { return nil }
        let remainingLength = previousLength - selection.length
        guard currentLength > remainingLength else { return nil }
        let insertedLength = currentLength - remainingLength
        guard selection.location <= currentLength,
              insertedLength <= currentLength - selection.location else { return nil }
        return NSRange(location: selection.location, length: insertedLength)
    }

    static func stillMatches(document: String, range: NSRange, pastedText: String) -> Bool {
        let source = document as NSString
        guard range.location != NSNotFound,
              range.location >= 0,
              range.length > 0,
              range.location <= source.length,
              range.length <= source.length - range.location else { return false }
        return source.substring(with: range) == pastedText
    }

    private static func normalizeNewlines(_ value: String) -> String {
        value.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    private static func matches(_ pattern: String, in value: String) -> [NSTextCheckingResult] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: value, range: NSRange(location: 0, length: (value as NSString).length))
    }

    private static func substring(_ match: NSTextCheckingResult, group: Int, in value: String) -> String? {
        guard group < match.numberOfRanges else { return nil }
        let range = match.range(at: group)
        guard range.location != NSNotFound else { return nil }
        return (value as NSString).substring(with: range)
    }

    private static func firstCapture(_ pattern: String, in value: String, group: Int) -> String? {
        guard let first = matches(pattern, in: value).first else { return nil }
        return substring(first, group: group, in: value)
    }

    private static func spanValue(_ name: String, in attributes: String) -> Int {
        let pattern = "(?i)\\b" + name + #"\s*=\s*["']?(\d+)"#
        guard let raw = firstCapture(pattern, in: attributes, group: 1),
              let n = Int(raw), n > 0 else { return 1 }
        return min(n, 256)
    }

    private static func cleanCell(_ cell: String) -> String {
        let withBreaks = cell
            .replacingOccurrences(of: #"(?i)<br\s*/?>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)</p\s*>"#, with: "\n", options: .regularExpression)
        let withoutTags = withBreaks.replacingOccurrences(of: #"(?s)<[^>]+>"#, with: "", options: .regularExpression)
        return decodeHTMLEntities(normalizeNewlines(withoutTags))
            .trimmingCharacters(in: .newlines)
    }

    private static func quoteTSV(_ cell: String) -> String {
        guard cell.contains("\t") || cell.contains("\n") || cell.contains("\"") else { return cell }
        return "\"" + cell.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func decodeHTMLEntities(_ source: String) -> String {
        let pattern = #"&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);"#
        let found = matches(pattern, in: source)
        guard !found.isEmpty else { return source }
        let ns = source as NSString
        var result = ""
        var cursor = 0
        for match in found {
            result += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let token = substring(match, group: 1, in: source) ?? ""
            let resolved: String?
            if token.hasPrefix("#x") || token.hasPrefix("#X") {
                resolved = UInt32(token.dropFirst(2), radix: 16).flatMap(UnicodeScalar.init).map(String.init)
            } else if token.hasPrefix("#") {
                resolved = UInt32(token.dropFirst(), radix: 10).flatMap(UnicodeScalar.init).map(String.init)
            } else {
                switch token.lowercased() {
                case "nbsp": resolved = " "
                case "amp": resolved = "&"
                case "lt": resolved = "<"
                case "gt": resolved = ">"
                case "quot": resolved = "\""
                case "apos": resolved = "'"
                case "ndash": resolved = "–"
                case "mdash": resolved = "—"
                default: resolved = nil
                }
            }
            result += resolved ?? ns.substring(with: match.range)
            cursor = NSMaxRange(match.range)
        }
        result += ns.substring(from: cursor)
        return result
    }
}
