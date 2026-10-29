import Foundation

/// Reuses the *existing* math/Mermaid assist snippets rather than maintaining
/// an independently divergent command catalog. This code is pure Foundation;
/// the AppKit popover uses its results but owns no Markdown syntax rules.
enum MarkdownSlashContextCore {
    /// nil: a protected code/Markmap/Markdown fence or generic code block.
    /// In Mermaid/LaTeX, slash is deliberately accepted only as the first
    /// non-whitespace token of a line, not inside an expression or edge label.
    static func context(in source: String, caretUTF16: Int) -> MarkdownEditingContext? {
        let ns = source as NSString
        let position = min(ns.length, max(0, caretUTF16))
        let prefix = ns.substring(to: position)
        var fence: MarkdownFenceSyntax.Fence?
        var math = false
        var mermaidLines: [String] = []
        for line in prefix.components(separatedBy: "\n") {
            if let active = fence {
                if MarkdownFenceSyntax.closes(line, fence: active) { fence = nil }
                else if active.language == "mermaid" { mermaidLines.append(line) }
                continue
            }
            if !math, let opening = MarkdownFenceSyntax.opening(line) {
                fence = opening
                mermaidLines = []
                continue
            }
            if MarkdownListSyntax.indentation(line) <= 3 &&
                line.trimmingCharacters(in: .whitespaces) == "$$" { math.toggle() }
        }
        if let fence {
            switch fence.language {
            case "mermaid": return MermaidEditingDialect.context(lines: mermaidLines)
            case "latex", "tex": return .math
            default: return nil // including markmap and other fenced text
            }
        }
        return math ? .math : .normal
    }

    static func trigger(in source: String, caretUTF16: Int,
                        selectionLength: Int = 0) -> (SlashCommandCore.Trigger, MarkdownEditingContext)? {
        guard let found = SlashCommandCore.trigger(in: source, caretUTF16: caretUTF16,
                                                    selectionLength: selectionLength),
              let context = context(in: source, caretUTF16: caretUTF16) else { return nil }
        let ns = source as NSString
        let line = ns.lineRange(for: NSRange(location: found.range.location, length: 0))
        let before = ns.substring(with: NSRange(location: line.location,
                                                 length: found.range.location - line.location))
        if context != .normal {
            guard before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        } else {
            // An inline `$expression / ...` or a backtick-code fragment should
            // never produce a Markdown insertion popover. Same for table cells.
            guard !before.trimmingCharacters(in: .whitespaces).hasPrefix("|"),
                  !insideInlineLiteral(before) else { return nil }
        }
        return (found, context)
    }

    private static func insideInlineLiteral(_ linePrefix: String) -> Bool {
        var insideCode = false
        var insideMath = false
        var escaped = false
        for character in linePrefix {
            if character == "\\" && !escaped { escaped = true; continue }
            if !escaped {
                if character == "`" { insideCode.toggle() }
                if character == "$" && !insideCode { insideMath.toggle() }
            }
            escaped = false
        }
        return insideCode || insideMath
    }

    static func matches(_ query: String, context: MarkdownEditingContext) -> [SlashCommandCore.Item] {
        if context == .normal { return SlashCommandCore.matches(query) }
        if context == .code { return [] }
        let symbol = context == .math ? "function" : "point.3.connected.trianglepath.dotted"
        let snippets = MarkdownAssistSnippet.allCases.filter { $0.context == context }
        let candidates: [SlashCommandCore.Item] = snippets.map { snippet in
            let preview = snippet.source.replacingOccurrences(of: "\n", with: " · ")
            return SlashCommandCore.Item(id: snippet.rawValue, title: snippet.title,
                description: String(preview.prefix(46)),
                keywords: snippet.group.title + " " + snippet.rawValue + " " + snippet.title + " " + snippet.source,
                source: snippet.source, caretBack: snippet.caretBack,
                symbol: symbol, isBlock: snippet.beginsOnNewLine)
        }
        let advanced = MemoWeaverDiagramExtraTools.items(for: context).map { item in
            let snippet = item.insertion()
            return SlashCommandCore.Item(id: item.id, title: item.title,
                description: String(item.source.replacingOccurrences(of: "\n", with: " · ").prefix(46)),
                keywords: context.slashPaletteTitle + " " + item.title,
                source: item.source, caretBack: snippet.caretBack,
                symbol: symbol, isBlock: item.beginsOnNewLine)
        }
        return SlashCommandCore.filter(candidates + advanced, query: query)
    }
}
