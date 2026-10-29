import Foundation

// Pasteboard-rich HTML/RTF sometimes decodes special symbols as U+FFFD.
// A separate Unicode plain-text flavor may still contain the intact source.
// Never guess what a replacement glyph was; prefer an actually readable
// clipboard representation, and never discard embedded attachments.
enum WorkOSPasteRecovery {
    static func replacementCount(in value: String) -> Int {
        value.unicodeScalars.reduce(0) { $0 + ($1.value == 0xFFFD ? 1 : 0) }
    }

    static func bestPlainText(_ candidates: [String]) -> String? {
        candidates.filter { !$0.isEmpty }
            .enumerated()
            .min { lhs, rhs in
                let l = replacementCount(in: lhs.element)
                let r = replacementCount(in: rhs.element)
                return l == r ? lhs.offset < rhs.offset : l < r
            }?.element
    }

    // Returns a verbatim Unicode alternative only when the AppKit *rich*
    // representation demonstrably contains more replacement characters.
    // An attached image would be lost when replacing the entire pasted span,
    // so leave attachment-bearing pastes untouched.
    static func replacementText(rich: String, unicodePlain: String?) -> String? {
        guard let unicodePlain, !unicodePlain.isEmpty,
              !rich.contains("\u{FFFC}"),
              replacementCount(in: rich) > replacementCount(in: unicodePlain),
              (unicodePlain as NSString).length <= 1_000_000 else { return nil }
        return unicodePlain
    }
}
