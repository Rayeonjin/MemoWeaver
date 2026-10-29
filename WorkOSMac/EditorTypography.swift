import AppKit

struct EditorTypography: Equatable {
    var size: CGFloat
    var lineHeight: CGFloat

    init(size: Double = EditorTypographyRules.defaultSize, lineHeight: Double = EditorTypographyRules.defaultLineHeight) {
        self.size = CGFloat(EditorTypographyRules.fontSize(size))
        self.lineHeight = CGFloat(EditorTypographyRules.lineHeight(lineHeight))
    }

    var extraLeading: CGFloat {
        CGFloat(EditorTypographyRules.extraLeading(fontSize: Double(size), lineHeight: Double(lineHeight)))
    }
    var paragraphSpacing: CGFloat { max(6, size * 0.4) }
    var bodyFont: NSFont { NSFont.systemFont(ofSize: size) }
    var defaultParagraphStyle: NSMutableParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.lineSpacing = extraLeading
        p.paragraphSpacing = paragraphSpacing
        p.lineBreakMode = .byWordWrapping
        return p
    }

    func standardTypingAttributes() -> [NSAttributedString.Key: Any] {
        [.font: bodyFont, .foregroundColor: NSColor.labelColor,
         .paragraphStyle: defaultParagraphStyle]
    }

    /// HTML saved by older versions often uses 14pt, while newer notes may
    /// already be 17pt or more. Guess the dominant plain-text point size to
    /// avoid magnifying bold text each time an edited note is reopened.
    static func inferredBodySize(in text: NSAttributedString) -> CGFloat {
        guard text.length > 0 else { return 14 }
        var normal: [Int: Int] = [:]
        var any: [Int: Int] = [:]
        text.enumerateAttributes(in: NSRange(location: 0, length: text.length), options: []) { attrs, range, _ in
            guard let font = attrs[.font] as? NSFont else { return }
            let size = Int(font.pointSize.rounded())
            guard size >= 9 && size <= 48 else { return }
            any[size, default: 0] += range.length
            if !NSFontManager.shared.traits(of: font).contains(.boldFontMask) {
                normal[size, default: 0] += range.length
            }
        }
        let values = normal.isEmpty ? any : normal
        let common = values.max { a, b in a.value < b.value }?.key ?? 14
        // A note containing only a large heading should not get a 28pt body.
        return CGFloat(common > 21 ? 14 : common)
    }

    /// Preserve semantic visual traits and decorations but avoid HTML-supplied
    /// fallback fonts and tiny browser-default point sizes on Korean text.
    /// This modifies the in-memory attributed text only, not the SQLite note.
    static func normalized(_ content: NSAttributedString, fromReferenceSize reference: CGFloat,
                           to settings: EditorTypography) -> NSAttributedString {
        let output = NSMutableAttributedString(attributedString: content)
        guard output.length > 0 else { return output }
        let entire = NSRange(location: 0, length: output.length)
        let original = content
        original.enumerateAttributes(in: entire, options: []) { attrs, range, _ in
            let originalFont = attrs[.font] as? NSFont ?? NSFont.systemFont(ofSize: reference)
            let traits = NSFontManager.shared.traits(of: originalFont)
            let isBold = traits.contains(.boldFontMask)
            let isItalic = traits.contains(.italicFontMask)
            let monospaced = originalFont.isFixedPitch && !(originalFont.familyName ?? "").lowercased().contains("system")
            let adjusted = CGFloat(EditorTypographyRules.displaySize(
                original: Double(originalFont.pointSize), referenceBody: Double(reference),
                preferredBody: Double(settings.size), bold: isBold))
            var replacement: NSFont = monospaced
                ? NSFont.monospacedSystemFont(ofSize: adjusted, weight: isBold ? .bold : .regular)
                : NSFont.systemFont(ofSize: adjusted, weight: isBold ? .bold : .regular)
            if isItalic { replacement = NSFontManager.shared.convert(replacement, toHaveTrait: .italicFontMask) }
            output.addAttribute(.font, value: replacement, range: range)

            let originalParagraph = attrs[.paragraphStyle] as? NSParagraphStyle
            let paragraph = (originalParagraph?.mutableCopy() as? NSMutableParagraphStyle)
                ?? settings.defaultParagraphStyle
            paragraph.lineSpacing = settings.extraLeading
            // Imported HTML can specify giant paragraph margins and clip long
            // lines. Keep authored blank lines, but not browser-only layout gaps.
            paragraph.paragraphSpacing = min(max(paragraph.paragraphSpacing, settings.paragraphSpacing),
                                             settings.size * 0.9)
            paragraph.paragraphSpacingBefore = min(max(0, paragraph.paragraphSpacingBefore),
                                                   settings.size * 0.9)
            paragraph.lineBreakMode = .byWordWrapping
            output.addAttribute(.paragraphStyle, value: paragraph, range: range)
        }
        // Important: never wipe foreground colors during typography changes.
        // RichDocument/EditorInk repairs hard-coded neutral colors on import.
        // Other user-selected colors are intentional document formatting.
        return output
    }
}

// Normalize external fonts at the moment of paste, not only after a note is
// reopened. Change attributes of the inserted span alone; preserve characters,
// the NSTextTableBlock hierarchy, links, emphasis and user-selected colors.
enum WorkOSPastedTypography {
    static func normalize(in storage: NSMutableAttributedString, range: NSRange,
                          typography: EditorTypography) -> Bool {
        guard range.location != NSNotFound, range.location >= 0, range.length > 0,
              range.location <= storage.length,
              range.length <= storage.length - range.location else { return false }
        let content = storage.attributedSubstring(from: range)
        let bodyReference = EditorTypography.inferredBodySize(in: content)
        var replacements: [(range: NSRange, font: NSFont, paragraph: NSMutableParagraphStyle?)] = []
        content.enumerateAttributes(in: NSRange(location: 0, length: content.length), options: []) { attrs, local, _ in
            let original = attrs[.font] as? NSFont ?? typography.bodyFont
            let traits = NSFontManager.shared.traits(of: original)
            let bold = traits.contains(.boldFontMask)
            let size = CGFloat(EditorTypographyRules.displaySize(
                original: Double(original.pointSize),
                referenceBody: Double(bodyReference),
                preferredBody: Double(typography.size), bold: bold))
            // SF/system sans serif uses the normal Apple glyph-fallback chain
            // for English, Hangul and emoji. Avoid tiny browser serif fonts.
            // An icon-font's private-use code points are *not* normal Unicode
            // characters: keep their original mapping instead of creating tofu.
            let run = (content.string as NSString).substring(with: local)
            if run.contains("\u{FFFC}") { return } // Preserve embedded attachments as-is.
            let privateGlyphs = run.unicodeScalars.contains {
                (0xE000...0xF8FF).contains($0.value) ||
                (0xF0000...0xFFFFD).contains($0.value) ||
                (0x100000...0x10FFFD).contains($0.value)
            }
            var font = privateGlyphs ? original
                : NSFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
            if !privateGlyphs && traits.contains(.italicFontMask) {
                font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
            }
            var paragraph: NSMutableParagraphStyle?
            if let existing = attrs[.paragraphStyle] as? NSParagraphStyle,
               existing.textBlocks.isEmpty,
               let copy = existing.mutableCopy() as? NSMutableParagraphStyle {
                copy.lineSpacing = typography.extraLeading
                copy.paragraphSpacing = min(max(copy.paragraphSpacing, typography.paragraphSpacing),
                                            typography.size * 0.9)
                copy.paragraphSpacingBefore = min(max(0, copy.paragraphSpacingBefore),
                                                  typography.size * 0.9)
                copy.lineBreakMode = .byWordWrapping
                paragraph = copy
            }
            replacements.append((NSRange(location: range.location + local.location, length: local.length),
                                 font, paragraph))
        }
        guard !replacements.isEmpty else { return false }
        storage.beginEditing()
        for item in replacements {
            storage.addAttribute(.font, value: item.font, range: item.range)
            if let paragraph = item.paragraph {
                storage.addAttribute(.paragraphStyle, value: paragraph, range: item.range)
            }
        }
        storage.endEditing()
        return true
    }
}
