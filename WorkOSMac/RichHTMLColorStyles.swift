import Foundation

// Cocoa's HTML exporter puts many text colors in CSS classes such as p.p1 and
// span.s2, not in style="..." on the element. The editor deliberately omits
// <style> on import (so it cannot load remote CSS or images). Before stripping
// it, copy ONLY safe CSS foreground hex colors into inline element attributes.
// Do not modify the saved note or any other styling, and do not load resources.
enum RichHTMLColorStyles {
    static func inlineForegroundColors(in html: String) -> String {
        guard html.range(of: "<style", options: [.caseInsensitive]) != nil else { return html }
        let styles = regex(#"(?is)<style\b[^>]*>(.*?)</style\s*>"#)
        let rules = regex(#"(?s)([^{}]+)\{([^{}]*)\}"#)
        let declaration = regex(#"(?i)(?:^|;)\s*color\s*:\s*(#[0-9a-f]{3}(?:[0-9a-f]{3})?)(?=\s*(?:;|$))"#)
        let selector = regex(#"(?i)^(?:(?:[a-z][a-z0-9-]*)?\.)?([a-z_][a-z0-9_-]*)$"#)
        let classes = regex(#"(?is)<(p|span|div|li|td|th|a|h[1-6])\b[^>]*\bclass\s*=\s*(['"])(.*?)\2[^>]*>"#)
        let styleAttribute = regex(#"(?i)\bstyle\s*=\s*(['"])(.*?)\1"#)
        let inlineColor = regex(#"(?i)(?:^|;)\s*color\s*:"#)
        var colors: [String: String] = [:]
        let entireHTML = NSRange(html.startIndex..<html.endIndex, in: html)
        for style in styles.matches(in: html, range: entireHTML) {
            guard let cssRange = Range(style.range(at: 1), in: html) else { continue }
            let css = String(html[cssRange])
            for rule in rules.matches(in: css, range: NSRange(css.startIndex..<css.endIndex, in: css)) {
                guard let ruleSelectors = Range(rule.range(at: 1), in: css),
                      let declarations = Range(rule.range(at: 2), in: css) else { continue }
                let declarationText = String(css[declarations])
                guard let color = declaration.firstMatch(in: declarationText,
                    range: NSRange(declarationText.startIndex..<declarationText.endIndex, in: declarationText)),
                    let colorRange = Range(color.range(at: 1), in: declarationText) else { continue }
                let hex = String(declarationText[colorRange]).uppercased()
                for item in css[ruleSelectors].split(separator: ",") {
                    let candidate = String(item).trimmingCharacters(in: .whitespacesAndNewlines)
                    let full = NSRange(candidate.startIndex..<candidate.endIndex, in: candidate)
                    guard let hit = selector.firstMatch(in: candidate, range: full),
                          hit.range == full,
                          let classRange = Range(hit.range(at: 1), in: candidate) else { continue }
                    colors[String(candidate[classRange])] = hex
                }
            }
        }
        guard !colors.isEmpty else { return html }
        var output = html
        let originalRanges = classes.matches(in: html, range: entireHTML)
        for match in originalRanges.reversed() {
            guard let tagRange = Range(match.range, in: output),
                  let classRange = Range(match.range(at: 3), in: output) else { continue }
            let names = output[classRange].split(whereSeparator: { $0.isWhitespace })
            guard let hex = names.compactMap({ colors[String($0)] }).last else { continue }
            let tag = String(output[tagRange])
            let fullTag = NSRange(tag.startIndex..<tag.endIndex, in: tag)
            let updated: String
            if let attribute = styleAttribute.firstMatch(in: tag, range: fullTag),
               let range = Range(attribute.range(at: 2), in: tag) {
                let existing = String(tag[range])
                guard inlineColor.firstMatch(in: existing,
                    range: NSRange(existing.startIndex..<existing.endIndex, in: existing)) == nil else { continue }
                var copy = tag
                copy.replaceSubrange(range, with: existing + "; color: " + hex)
                updated = copy
            } else {
                // The only injected value is a validated hex color, never CSS/JS from the input.
                let position = tag.index(before: tag.endIndex)
                updated = String(tag[..<position]) + " style=\"color: \(hex)\">"
            }
            output.replaceSubrange(tagRange, with: updated)
        }
        return output
    }

    private static func regex(_ pattern: String) -> NSRegularExpression {
        // All patterns are constant expressions under our control.
        try! NSRegularExpression(pattern: pattern)
    }
}
