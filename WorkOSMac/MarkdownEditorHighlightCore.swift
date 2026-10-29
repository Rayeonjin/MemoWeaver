import Foundation

/// Display-only Markdown color spans. All locations and lengths are UTF-16,
/// matching NSTextStorage/NSLayoutManager even for Korean and emoji.
/// No replacement, normalization, or attributed content is ever persisted.
enum MarkdownEditorHighlightCore {
    enum Kind: Equatable {
        case heading, listMarker, checkbox, quoteMarker
        case fence, inlineCode, emphasisMarker, link, mathDelimiter
    }
    struct Span: Equatable {
        let kind: Kind
        let range: NSRange
    }

    private static func expression(_ source: String) -> NSRegularExpression {
        // These patterns are compile-time constants, not derived from notes.
        try! NSRegularExpression(pattern: source)
    }
    private static let heading = expression(#"^[ ]{0,3}#{1,6}(?=[ \t]+)"#)
    private static let list = expression(#"^[ \t]*([-+*]|[0-9]{1,9}[.)])(?=[ \t]+)"#)
    private static let checkbox = expression(#"^[ \t]*(?:[-+*]|[0-9]{1,9}[.)])[ \t]+(\[[ xX]\])(?=[ \t]|$)"#)
    private static let quote = expression(#"^[ ]{0,3}(>+)"#)
    private static let inlineCode = expression(#"(`+)([^`\r\n]|`(?!\1))+?\1"#)
    private static let link = expression(#"!?\[[^\]\r\n]*\]\([^\)\r\n]*\)"#)
    private static let bold = expression(#"(\*\*|__)(?=\S).+?(?<=\S)\1"#)
    private static let italic = expression(#"(?<!\*)\*(?!\*)(?=\S)[^*\r\n]+?(?<=\S)\*(?!\*)"#)
    private static let math = expression(#"(?<!\$)\$(?!\$)(?=\S)[^\$\r\n]+?(?<=\S)\$(?!\$)"#)

    static func spans(in source: String) -> [Span] {
        var result: [Span] = []
        var fence: MarkdownFenceSyntax.Fence?
        var inDisplayMath = false
        var utf16Start = 0

        // NSString splits LF code units inside CRLF grapheme clusters.
        for raw in (source as NSString).components(separatedBy: "\n") {
            // Keep the original UTF-16 offset even for Windows CRLF input.
            let line = raw.hasSuffix("\r") ? String(raw.dropLast()) : raw
            let length = (line as NSString).length
            let whole = NSRange(location: 0, length: length)
            func add(_ kind: Kind, _ local: NSRange) {
                guard local.location != NSNotFound, local.length > 0,
                      NSMaxRange(local) <= length else { return }
                result.append(Span(kind: kind,
                                   range: NSRange(location: utf16Start + local.location,
                                                  length: local.length)))
            }
            func first(_ regex: NSRegularExpression) -> NSTextCheckingResult? {
                regex.firstMatch(in: line, range: whole)
            }
            func matches(_ regex: NSRegularExpression, _ body: @escaping (NSRange) -> Void) {
                regex.enumerateMatches(in: line, range: whole) { match, _, _ in
                    if let match { body(match.range) }
                }
            }
            if let active = fence {
                if MarkdownFenceSyntax.closes(line, fence: active) { // don't color embedded source
                    add(.fence, whole)
                    fence = nil
                }
            } else if let opening = MarkdownFenceSyntax.opening(line), !inDisplayMath {
                add(.fence, whole)
                fence = opening
            } else if MarkdownListSyntax.indentation(line) <= 3,
                      line.trimmingCharacters(in: .whitespaces) == "$$" {
                add(.mathDelimiter, whole)
                inDisplayMath.toggle()
            } else if !inDisplayMath {
                // Indented code is source, not a Markdown heading or list.
                if MarkdownListSyntax.indentation(line) < 4 {
                    if first(heading) != nil { add(.heading, whole) }
                    if let match = first(list) { add(.listMarker, match.range(at: 1)) }
                    if let match = first(checkbox) { add(.checkbox, match.range(at: 1)) }
                    if let match = first(quote) { add(.quoteMarker, match.range(at: 1)) }

                    var codeRanges: [NSRange] = []
                    matches(inlineCode) { range in
                        codeRanges.append(range)
                        add(.inlineCode, range)
                    }
                    func outsideCode(_ range: NSRange) -> Bool {
                        !codeRanges.contains(where: { NSIntersectionRange($0, range).length > 0 })
                    }
                    matches(link) { range in
                        if outsideCode(range) { add(.link, range) }
                    }
                    matches(bold) { range in
                        guard outsideCode(range), range.length >= 4 else { return }
                        add(.emphasisMarker, NSRange(location: range.location, length: 2))
                        add(.emphasisMarker, NSRange(location: NSMaxRange(range) - 2, length: 2))
                    }
                    matches(italic) { range in
                        guard outsideCode(range), range.length >= 2 else { return }
                        add(.emphasisMarker, NSRange(location: range.location, length: 1))
                        add(.emphasisMarker, NSRange(location: NSMaxRange(range) - 1, length: 1))
                    }
                    matches(math) { range in
                        guard outsideCode(range), range.length >= 2 else { return }
                        add(.mathDelimiter, NSRange(location: range.location, length: 1))
                        add(.mathDelimiter, NSRange(location: NSMaxRange(range) - 1, length: 1))
                    }
                }
            }
            utf16Start += (raw as NSString).length + 1
        }
        return result
    }
}
