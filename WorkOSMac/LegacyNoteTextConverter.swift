import Foundation

// Non-destructive display conversion for v0.8.x HTML notes.
// This NEVER writes to SQLite. The original HTML and extension block JSON are
// preserved on the first actual text edit, after a successful SQLite snapshot.
// Text that has no recognizable HTML wrapper is returned byte-for-byte.
enum LegacyNoteTextConverter {
    private static let markup = #"(?i)<\s*(?:!doctype|html|head|body|p|div|br|span|font|h[1-6]|ul|ol|li|pre|code|blockquote|table|thead|tbody|tr|th|td|strong|em|b|i|u|style)\b"#

    static func editableText(for note: WorkNote) -> String {
        if note.isMarkdown { return note.bodyHTML }
        let raw = WorkOSJSON.dictionary(note.rawJSON)
        let legacyCapture = raw["quickCaptureText"] as? String
        let body: String
        if let legacyCapture, note.bodyHTML == WorkOSQuickCapture.html(legacyCapture) {
            // The original TXT scratchpad characters are still available.
            // Preserve spaces/newlines/tabs and Markdown punctuation exactly.
            body = legacyCapture
        } else {
            body = text(from: note.bodyHTML)
        }
        let blocks = note.workosBlocks.map { block -> String in
            switch block.kind {
            case .table:
                return block.source
            case .equation:
                return "$$\n" + block.source + "\n$$"
            case .mermaid:
                return "```mermaid\n" + block.source + "\n```"
            }
        }
        guard !blocks.isEmpty else { return body }
        let divider = body.isEmpty ? "" : (body.hasSuffix("\n") ? "\n" : "\n\n")
        return body + divider + blocks.joined(separator: "\n\n")
    }

    static func containsComplexContent(_ html: String) -> Bool {
        html.range(of: #"(?i)<\s*(?:img|object|iframe|svg|video|audio|attachment)\b|\b(?:rowspan|colspan)\s*="#,
                   options: .regularExpression) != nil
    }

    static func text(from input: String) -> String {
        guard input.range(of: markup, options: .regularExpression) != nil else {
            return input // raw VS Code / TXT note, including trailing whitespace
        }
        var html = input
        for pattern in [#"(?is)<!--.*?-->"#,
                        #"(?is)<head\b[^>]*>.*?</head\s*>"#,
                        #"(?is)<(?:style|script|noscript|template)\b[^>]*>.*?</(?:style|script|noscript|template)\s*>"#] {
            html = replace(html, pattern, "")
        }
        // Keep tabular content editable. A simple table becomes a Markdown
        // table; irregular/broken tables fall back to tab-separated text.
        if let re = try? NSRegularExpression(pattern: #"(?is)<table\b[^>]*>.*?</table\s*>"#) {
            for match in re.matches(in: html, range: NSRange(location: 0, length: (html as NSString).length)).reversed() {
                let original = (html as NSString).substring(with: match.range)
                let replacement = "\n\n" + tableText(original) + "\n\n"
                if let range = Range(match.range, in: html) { html.replaceSubrange(range, with: replacement) }
            }
        }
        for level in 1...6 {
            html = replace(html, #"(?i)<h"# + String(level) + #"\b[^>]*>"#, "\n" + String(repeating: "#", count: level) + " ")
        }
        // Visible link labels alone can lose important URLs from old notes.
        // Preserve both when the HTML contains an explicit destination.
        if let links = try? NSRegularExpression(pattern: #"(?is)<a\b[^>]*\bhref\s*=\s*['\"]([^'\"]+)['\"][^>]*>(.*?)</a\s*>"#) {
            for match in links.matches(in: html, range: NSRange(location: 0, length: (html as NSString).length)).reversed() {
                let ns = html as NSString
                let url = decodeEntities(ns.substring(with: match.range(at: 1)))
                let label = text(from: ns.substring(with: match.range(at: 2)))
                let displayed = label.isEmpty ? url : (label == url ? url : "[" + label + "](" + url + ")")
                if let range = Range(match.range, in: html) { html.replaceSubrange(range, with: displayed) }
            }
        }
        html = replace(html, #"(?i)<br\b[^>]*>"#, "\n")
        html = replace(html, #"(?i)<li\b[^>]*>"#, "- ")
        html = replace(html, #"(?i)</(?:li|p|div|h[1-6]|blockquote|tr)\s*>"#, "\n")
        html = replace(html, #"(?i)<(?:p|div|ul|ol|blockquote|html|body)\b[^>]*>"#, "")
        html = replace(html, #"(?i)</?(?:pre|code|strong|em|b|i|u)\b[^>]*>"#, "")
        // HTML tags are removed BEFORE entity unescaping: escaped literal <...>
        // from a VS Code note must remain literal text after conversion.
        html = replace(html, #"(?s)</?[^>]+>"#, "")
        html = decodeEntities(html)
        // Remove HTML-wrapper blank lines, never strip indentation within lines.
        while html.hasPrefix("\n") { html.removeFirst() }
        while html.hasSuffix("\n") { html.removeLast() }
        return html
    }

    private static func tableText(_ table: String) -> String {
        guard let rowRE = try? NSRegularExpression(pattern: #"(?is)<tr\b[^>]*>(.*?)</tr\s*>"#),
              let cellRE = try? NSRegularExpression(pattern: #"(?is)<(?:th|td)\b[^>]*>(.*?)</(?:th|td)\s*>"#) else {
            return textWithoutTable(table)
        }
        let rows: [[String]] = rowRE.matches(in: table, range: NSRange(location: 0, length: (table as NSString).length)).map { row in
            let portion = (table as NSString).substring(with: row.range(at: 1))
            return cellRE.matches(in: portion, range: NSRange(location: 0, length: (portion as NSString).length)).map { cell in
                let html = (portion as NSString).substring(with: cell.range(at: 1))
                return decodeEntities(text(from: html)).replacingOccurrences(of: "\n", with: " ")
            }
        }.filter { !$0.isEmpty }
        guard let count = rows.first?.count, count > 0 else { return textWithoutTable(table) }
        if rows.allSatisfy({ $0.count == count }) && count <= 24 && rows.count <= 300 {
            return WorkOSTable.markdown(rows)
        }
        return rows.map { $0.joined(separator: "\t") }.joined(separator: "\n")
    }

    private static func textWithoutTable(_ html: String) -> String {
        decodeEntities(replace(replace(html, #"(?i)</(?:td|th)\s*>"#, "\t"), #"(?s)</?[^>]+>"#, ""))
    }

    private static func replace(_ input: String, _ pattern: String, _ result: String) -> String {
        input.replacingOccurrences(of: pattern, with: result, options: .regularExpression)
    }

    private static func decodeEntities(_ input: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"&(?:#(?:[xX][0-9a-fA-F]+|[0-9]+)|[a-zA-Z]+);"#) else { return input }
        let names: [String: String] = ["amp":"&", "lt":"<", "gt":">", "quot":"\"", "apos":"'",
                                       "nbsp":" ", "hellip":"…", "mdash":"—", "ndash":"–",
                                       "bull":"•", "copy":"©", "reg":"®", "times":"×"]
        var value = input
        let ns = input as NSString
        for match in regex.matches(in: input, range: NSRange(location: 0, length: ns.length)).reversed() {
            let item = ns.substring(with: match.range)
            let core = String(item.dropFirst().dropLast())
            var decoded: String?
            if core.hasPrefix("#") {
                let number = core.dropFirst()
                let hex = number.first == "x" || number.first == "X"
                let digits = hex ? String(number.dropFirst()) : String(number)
                if let scalarValue = UInt32(digits, radix: hex ? 16 : 10),
                   let scalar = UnicodeScalar(scalarValue) { decoded = String(scalar) }
            } else {
                decoded = names[core.lowercased()]
            }
            if let decoded, let range = Range(match.range, in: value) { value.replaceSubrange(range, with: decoded) }
        }
        return value
    }
}
