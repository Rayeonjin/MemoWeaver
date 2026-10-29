import Foundation

// Explicit, reversible transformation of a source Markdown table into TSV.
// Unlike clipboard paste, this never guesses or reformats ordinary prose.
// Only a valid >=2-column table at the selection/caret is offered for conversion.
enum MarkdownTableTextCore {
    struct Conversion {
        let range: NSRange       // UTF-16 source range, compatible with NSTextView
        let tsv: String
    }

    private struct SourceLine {
        let text: String
        let offset: Int
        var length: Int { (text as NSString).length }
        var end: Int { offset + length }
    }

    static func conversion(in source: String, selection: NSRange) -> Conversion? {
        let ns = source as NSString
        guard ns.length > 0, ns.length <= 2_000_000,
              selection.location != NSNotFound, selection.location >= 0,
              selection.length >= 0, selection.location <= ns.length,
              selection.length <= ns.length - selection.location else { return nil }

        // Work line-wise, not regex substitution: escaped pipes and Korean text
        // are handled as ordinary characters without UTF-16 boundary surprises.
        let raw = source.components(separatedBy: "\n")
        var lines: [SourceLine] = []
        lines.reserveCapacity(raw.count)
        var offset = 0
        for text in raw {
            lines.append(SourceLine(text: text, offset: offset))
            offset += (text as NSString).length + 1
        }
        // Determine fenced-code membership just once. Do not rescan a long
        // note's prefix for every candidate row under a context-menu click.
        var insideFenced = [Bool](repeating: false, count: lines.count)
        var fenceMarker: String? = nil
        for index in lines.indices {
            let trimmed = lines[index].text.trimmingCharacters(in: .whitespaces)
            insideFenced[index] = fenceMarker != nil
            if let marker = fenceMarker {
                if trimmed.hasPrefix(marker) { fenceMarker = nil }
            } else if trimmed.hasPrefix("```") {
                fenceMarker = "```"
            } else if trimmed.hasPrefix("~~~") {
                fenceMarker = "~~~"
            }
        }
        let caret = selection.location
        let selectionEnd = NSMaxRange(selection)
        guard let anchor = lines.indices.first(where: { index in
            let line = lines[index]
            return caret >= line.offset && caret <= line.end
        }) else { return nil }

        // Scan the table around the selected line. We search backwards to its
        // separator/header rather than interpreting a table-looking body row
        // in isolation. A code fence cannot be treated as a table.
        var candidates: [Int] = []
        for index in stride(from: min(anchor, lines.count - 1), through: max(0, anchor - 450), by: -1) {
            candidates.append(index)
        }
        for start in candidates {
            guard start + 1 < lines.count,
                  let header = splitRow(lines[start].text),
                  let divider = splitRow(lines[start + 1].text),
                  header.count >= 2, header.count <= 24,
                  divider.count == header.count,
                  divider.allSatisfy(isSeparatorCell) else { continue }
            // Reject code fences, never silently transform literal examples.
            if insideFenced[start] { continue }
            var rows = [header]
            var cursor = start + 2
            while cursor < lines.count && rows.count < 301,
                  let cells = splitRow(lines[cursor].text), cells.count == header.count {
                rows.append(cells)
                cursor += 1
            }
            let sourceStart = lines[start].offset
            let sourceEnd = lines[cursor - 1].end
            // Only a selection entirely inside this table is eligible. If a
            // selection includes neighboring prose, refuse to touch anything.
            let includesFinalLineBreak = selectionEnd == sourceEnd + 1 &&
                sourceEnd < ns.length && ns.character(at: sourceEnd) == 0x000A
            guard caret >= sourceStart && caret <= sourceEnd,
                  (selectionEnd <= sourceEnd || includesFinalLineBreak) else { continue }
            guard rows.count <= 300 else { return nil }
            let tsv = rows.map { row in row.map(quoteTSV).joined(separator: "\t") }
                .joined(separator: "\n")
            return Conversion(range: NSRange(location: sourceStart,
                                             length: sourceEnd - sourceStart), tsv: tsv)
        }
        return nil
    }

    // Markdown's escaped delimiters, optional outer pipes, and 2+ columns.
    private static func splitRow(_ input: String) -> [String]? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.contains("|") else { return nil }
        if text.first == "|" { text.removeFirst() }
        // An ending escaped pipe is a cell value, not a structural delimiter.
        if text.last == "|" {
            let precedingBackslashes = text.dropLast().reversed().prefix(while: { $0 == "\\" }).count
            if precedingBackslashes % 2 == 0 { text.removeLast() }
        }
        var cells: [String] = []
        var cell = ""
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let character = chars[i]
            if character == "\\", i + 1 < chars.count,
               chars[i + 1] == "|" || chars[i + 1] == "\\" {
                cell.append(chars[i + 1]); i += 2; continue
            }
            if character == "|" { cells.append(normalize(cell)); cell = "" }
            else { cell.append(character) }
            i += 1
        }
        cells.append(normalize(cell))
        return cells.count >= 2 && cells.count <= 24 ? cells : nil
    }

    private static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)
    }

    private static func isSeparatorCell(_ cell: String) -> Bool {
        let value = cell.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return false }
        let noEdgeColons = value.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        return noEdgeColons.count >= 3 && noEdgeColons.allSatisfy { $0 == "-" } &&
               value.filter { $0 == ":" }.count <= 2 &&
               (!value.contains(":") || (value.first == ":" || value.last == ":"))
    }

    private static func quoteTSV(_ cell: String) -> String {
        guard cell.contains("\t") || cell.contains("\n") || cell.contains("\"") else { return cell }
        return "\"" + cell.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
