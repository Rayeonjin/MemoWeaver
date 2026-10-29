import Foundation

/// Pure typography rules, independent of SwiftUI, AppKit, and stored note HTML.
/// The editor applies these choices only to in-memory presentation until the
/// user really edits the document; changing a preference does not write a note.
enum EditorTypographyRules {
    static let defaultSize = 17.0
    static let defaultLineHeight = 1.5
    static let minimumSize = 13.0
    static let maximumSize = 24.0

    static func fontSize(_ candidate: Double) -> Double {
        guard candidate.isFinite else { return defaultSize }
        return min(max(candidate, minimumSize), maximumSize)
    }

    static func lineHeight(_ candidate: Double) -> Double {
        guard candidate.isFinite else { return defaultLineHeight }
        return min(max(candidate, 1.2), 1.8)
    }

    /// Native line-height is larger than raw glyph size. Add leading rather
    /// than setting minimumLineHeight, which clips some Hangul glyphs/emoji.
    static func extraLeading(fontSize: Double, lineHeight: Double) -> Double {
        self.fontSize(fontSize) * (self.lineHeight(lineHeight) - 1.0) * 0.65
    }

    /// Preserve old WorkOS heading hierarchy when normalizing HTML imports.
    /// HTML body fonts may be 12, 14, or browser-default serif; body uses the
    /// user's preferred size while bold headings keep proportional prominence.
    static func displaySize(original: Double, referenceBody: Double, preferredBody: Double, bold: Bool) -> Double {
        let base = fontSize(preferredBody)
        let reference = max(referenceBody, 1)
        let ratio = original / reference
        if bold && ratio >= 1.52 { return base * 1.64 }  // H1
        if bold && ratio >= 1.24 { return base * 1.35 }  // H2
        if bold && ratio >= 1.07 { return base * 1.12 }  // H3
        return base
    }

    static func zoom(_ previous: Double, by delta: Double) -> Double {
        fontSize(previous + delta)
    }
}
