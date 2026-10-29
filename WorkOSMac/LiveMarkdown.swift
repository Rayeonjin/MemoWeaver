import Foundation

// Pure UTF-16 range matcher for Notion-style keyboard shortcuts. Kept separate
// from AppKit so input edge cases can be tested without a Mac UI.
enum LiveMarkdown {
    enum InlineKind: Equatable {
        case bold, italic, strikethrough, code, link(String)
    }

    struct InlineMatch: Equatable {
        let range: NSRange
        let contentRange: NSRange
        let kind: InlineKind
    }

    enum BlockKind: Equatable {
        case heading(Int), quote, bullet, numbered, checklist(Bool)
    }

    struct BlockMatch: Equatable {
        let range: NSRange
        let replacement: String
        let kind: BlockKind
    }

    static func inline(in string: String, caret: Int) -> InlineMatch? {
        let text = string as NSString
        guard caret > 0, caret <= text.length else { return nil }
        let paragraphStart = text.lineRange(for: NSRange(location: caret - 1, length: 0)).location
        let fragment = text.substring(with: NSRange(location: paragraphStart, length: caret - paragraphStart))
        // Avoid running regular expressions on every ordinary keystroke.
        guard let last = fragment.last, "*_~`)".contains(last) else { return nil }
        // A completed closing marker is the trigger; partial markup stays visible.
        // The link case must be checked before italic because URLs contain punctuation.
        let patterns: [(String, InlineKind)] = [
            (#"\[([^\]\n]+)\]\((https?://[^\s\)]+)\)$"#, .link("")),
            (#"(?<!\*)\*\*([^\n*]+)\*\*$"#, .bold),
            (#"(?<!_)__([^\n_]+)__$"#, .bold),
            (#"(?<!~)~~([^\n~]+)~~$"#, .strikethrough),
            (#"(?<!`)`([^\n`]+)`$"#, .code),
            (#"(?<!\*)\*([^\n*]+)\*$"#, .italic),
            (#"(?<!_)_([^\n_]+)_$"#, .italic)
        ]
        let nsFragment = fragment as NSString
        let full = NSRange(location: 0, length: nsFragment.length)
        for (pattern, style) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: fragment, range: full),
                  NSMaxRange(match.range) == full.length,
                  match.range(at: 1).length > 0 else { continue }
            var resolved = style
            if case .link = style {
                let href = nsFragment.substring(with: match.range(at: 2))
                guard URL(string: href) != nil else { continue }
                resolved = .link(href)
            }
            return InlineMatch(
                range: NSRange(location: paragraphStart + match.range.location, length: match.range.length),
                contentRange: NSRange(location: paragraphStart + match.range(at: 1).location, length: match.range(at: 1).length),
                kind: resolved)
        }
        return nil
    }

    static func block(in string: String, caret: Int) -> BlockMatch? {
        let text = string as NSString
        guard caret > 0, caret <= text.length else { return nil }
        let paragraphStart = text.lineRange(for: NSRange(location: caret - 1, length: 0)).location
        let value = text.substring(with: NSRange(location: paragraphStart, length: caret - paragraphStart))
        guard value.last == " " else { return nil }
        let parsed: (String, BlockKind)?
        switch value {
        case "# ": parsed = ("", .heading(1))
        case "## ": parsed = ("", .heading(2))
        case "### ": parsed = ("", .heading(3))
        case "> ": parsed = ("", .quote)
        case "- ", "* ": parsed = ("• ", .bullet)
        case "- [ ] ": parsed = ("☐ ", .checklist(false))
        case "- [x] ", "- [X] ": parsed = ("☑ ", .checklist(true))
        default:
            if value.range(of: #"^[0-9]{1,3}\. $"#, options: .regularExpression) != nil {
                parsed = (value, .numbered)
            } else {
                parsed = nil
            }
        }
        guard let (replacement, kind) = parsed else { return nil }
        return BlockMatch(range: NSRange(location: paragraphStart, length: (value as NSString).length),
                          replacement: replacement, kind: kind)
    }

    // Used after Return so a visual list continues without typing another marker.
    // Empty items should be treated as a request to leave the list.
    static func continuation(after previousLine: String) -> (prefix: String, empty: Bool)? {
        if previousLine.hasPrefix("• ") { return ("• ", previousLine == "• ") }
        if previousLine.hasPrefix("☐ ") || previousLine.hasPrefix("☑ ") {
            return ("☐ ", previousLine == "☐ " || previousLine == "☑ ")
        }
        if let regex = try? NSRegularExpression(pattern: #"^([0-9]{1,3})\. "#),
           let match = regex.firstMatch(in: previousLine,
               range: NSRange(location: 0, length: (previousLine as NSString).length)),
           let number = Int((previousLine as NSString).substring(with: match.range(at: 1))),
           number < 999 {
            let prefix = "\(number + 1). "
            return (prefix, (previousLine as NSString).length == match.range.length)
        }
        return nil
    }
}
