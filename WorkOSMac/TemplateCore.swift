import Foundation

// Reusable Telegram texts and AI prompts: {{variable}} placeholders, no network.
enum WorkOSTemplate {
    private static let pattern = #"\{\{\s*([^{}\n]+?)\s*\}\}"#
    private static var matcher: NSRegularExpression {
        try! NSRegularExpression(pattern: pattern)
    }

    static func variables(in source: String) -> [String] {
        let sourceNS = source as NSString
        let matches = matcher.matches(in: source, range: NSRange(location: 0, length: sourceNS.length))
        var seen: Set<String> = []
        var result: [String] = []
        for match in matches {
            let key = sourceNS.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty && !seen.contains(key) { seen.insert(key); result.append(key) }
        }
        return result
    }

    static func fill(_ source: String, values: [String: String]) -> String {
        let sourceNS = source as NSString
        let matches = matcher.matches(in: source, range: NSRange(location: 0, length: sourceNS.length))
        var result = source
        for match in matches.reversed() {
            let key = sourceNS.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let value = values[key] else { continue }
            guard let range = Range(match.range, in: result) else { continue }
            result.replaceSubrange(range, with: value)
        }
        return result
    }

    static func plain(_ markdown: String) -> String {
        var text = markdown
        let rules: [(String, String)] = [
            (#"(?m)^#{1,6}\s+"#, ""),
            (#"\*\*(.+?)\*\*"#, "$1"),
            (#"(?<!\*)\*([^*\n]+)\*(?!\*)"#, "$1"),
            (#"~~(.+?)~~"#, "$1"),
            (#"`([^`\n]+)`"#, "$1"),
            (#"(?m)^\s*[-*]\s+\[[xX ]\]\s+"#, "- ")
        ]
        for (expression, replacement) in rules {
            text = text.replacingOccurrences(of: expression, with: replacement,
                                             options: .regularExpression)
        }
        return text
    }
}
