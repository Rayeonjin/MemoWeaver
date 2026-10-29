import AppKit
import CoreText

/// Paints line numbers *inside the NSTextView's existing left margin*.
/// Unlike a ruler or scroll-view overlay, this does not create or attach views,
/// resize the clip/text container, intercept events, or change persisted text.
final class WorkOSLineNumberPainter {
    static let gutterWidth: CGFloat = 44
    private var starts: [Int] = [0]
    private var dirty = true
    private let numberFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)

    func invalidate() { dirty = true }
    func updateAfterEdit(in source: String, editedRange: NSRange, delta: Int) {
        if !dirty {
            starts = EditorLineNumberRules.updatedLineStarts(
                previous: starts, newText: source,
                editedRange: editedRange, changeInLength: delta)
        }
    }

    /// Positions are in NSTextView document coordinates, not scroll coordinates.
    /// y is the *label's top*, calculated from the text glyph's baseline.
    /// A soft-wrapped visual row is deliberately NOT assigned a new number.
    func visiblePlacements(in editor: NSTextView, rect: NSRect) -> [(number: Int, y: CGFloat, height: CGFloat)] {
        guard let manager = editor.layoutManager,
              let container = editor.textContainer else { return [] }
        if dirty {
            starts = EditorLineNumberRules.lineStarts(in: editor.string)
            dirty = false
        }
        let origin = editor.textContainerOrigin
        let characters = editor.string as NSString
        let textLength = characters.length
        let font = editor.font ?? (editor.typingAttributes[.font] as? NSFont)
            ?? NSFont.monospacedSystemFont(ofSize: 17, weight: .regular)
        let defaultBaselineOffset = manager.defaultBaselineOffset(for: font)
        if textLength == 0 {
            let height = manager.defaultLineHeight(for: font)
            return [(1, origin.y + defaultBaselineOffset - numberFont.ascender, height)]
        }
        let visible = rect.intersection(editor.visibleRect)
        guard !visible.isNull, !visible.isEmpty else { return [] }
        let containerRect = NSRect(x: 0,
                                   y: max(0, visible.minY - origin.y),
                                   width: max(1, editor.bounds.width - origin.x),
                                   height: visible.height + 2 * (editor.font?.pointSize ?? 17))
        let glyphRange = manager.glyphRange(forBoundingRect: containerRect, in: container)
        let characterRange = manager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        guard characterRange.location != NSNotFound else { return [] }
        let first = EditorLineNumberRules.lineIndex(forUTF16Offset: characterRange.location, starts: starts)
        let last = EditorLineNumberRules.lineIndex(forUTF16Offset: min(textLength, NSMaxRange(characterRange)), starts: starts)
        guard first <= last else { return [] }
        // Blank, spaces-only, and tab-only Markdown paragraphs have no visible
        // glyph with a meaningful typographic baseline.  Use TextKit's default
        // baseline for the editor's actual monospaced font *inside each row's
        // own line fragment*.  Do not borrow a baseline from neighboring rows:
        // font fallback, wrapping and different paragraph metrics can produce
        // different glyph positions even when the user sees uniform text.
        // Visible text rows still use their own TextKit glyph baselines.
        func firstInkCharacter(onLine index: Int) -> Int? {
            guard index >= 0 && index < starts.count else { return nil }
            let from = starts[index]
            let to = index + 1 < starts.count ? starts[index + 1] : textLength
            guard from < to else { return nil }
            var cursor = from
            while cursor < to {
                switch characters.character(at: cursor) {
                case 0x0009, 0x000A, 0x000B, 0x000C, 0x000D,
                     0x0020, 0x00A0, 0x2028, 0x2029:
                    cursor += 1
                default:
                    return cursor
                }
            }
            return nil
        }
        var placements: [(number: Int, y: CGFloat, height: CGFloat)] = []
        for index in first...last {
            let position = starts[index]
            let fragment: NSRect
            let labelY: CGFloat
            if position < textLength {
                let glyph = manager.glyphIndexForCharacter(at: position)
                guard glyph < manager.numberOfGlyphs else { continue }
                fragment = manager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
                let nativeBaseline = manager.location(forGlyphAt: glyph).y
                let baselineOffset: CGFloat
                if let inkPosition = firstInkCharacter(onLine: index) {
                    let inkGlyph = manager.glyphIndexForCharacter(at: inkPosition)
                    if inkGlyph < manager.numberOfGlyphs &&
                        abs(manager.lineFragmentRect(forGlyphAt: inkGlyph,
                                                     effectiveRange: nil).minY - fragment.minY) < 0.5 {
                        baselineOffset = manager.location(forGlyphAt: inkGlyph).y
                    } else {
                        // An extreme indentation can wrap before real text.
                        baselineOffset = nativeBaseline
                    }
                } else {
                    baselineOffset = defaultBaselineOffset
                }
                labelY = origin.y + fragment.minY + baselineOffset - numberFont.ascender
            } else if manager.extraLineFragmentTextContainer != nil {
                fragment = manager.extraLineFragmentRect
                labelY = origin.y + fragment.minY + defaultBaselineOffset - numberFont.ascender
            } else {
                continue
            }
            let lineY = origin.y + fragment.minY
            if lineY + fragment.height >= visible.minY - 4 && lineY <= visible.maxY + 4 {
                placements.append((index + 1, labelY.isFinite ? labelY : lineY, fragment.height))
            }
        }
        return placements
    }

    func draw(in editor: NSTextView, dirtyRect: NSRect) {
        // The document text is already painted by NSTextView.draw. Draw only
        // inside the pre-existing textContainerInset; never cover text glyphs.
        let safeWidth = min(Self.gutterWidth, max(0, editor.textContainerOrigin.x - 4))
        guard safeWidth >= 25 else { return }
        let gutter = NSRect(x: 0, y: dirtyRect.minY, width: safeWidth,
                            height: dirtyRect.height)
        NSColor.textBackgroundColor.setFill()
        NSBezierPath(rect: gutter).fill()
        // Drawing with NSAttributedString.draw(in:) uses its own TextKit line
        // box and leading, so setting the rectangle top to (baseline-ascent)
        // does NOT guarantee its visible glyph aligns with the editor's text.
        // CoreText draws directly at the exact baseline computed above.
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        for placement in visiblePlacements(in: editor, rect: dirtyRect) {
            let text = NSAttributedString(string: String(placement.number), attributes: [
                .font: numberFont,
                .foregroundColor: NSColor.secondaryLabelColor
            ])
            let line = CTLineCreateWithAttributedString(text)
            let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            let x = max(2, safeWidth - 10 - width)
            let baseline = placement.y + numberFont.ascender
            ctx.saveGState()
            ctx.textMatrix = .identity
            // Canvas coordinates are top-down. Flip only the CoreText glyphs
            // around the chosen baseline; text origin/fragment stay unchanged.
            ctx.translateBy(x: x, y: baseline)
            ctx.scaleBy(x: 1, y: -1)
            CTLineDraw(line, ctx)
            ctx.restoreGState()
        }
        NSColor.separatorColor.withAlphaComponent(0.4).setStroke()
        let divider = NSBezierPath()
        divider.move(to: NSPoint(x: safeWidth - 0.5, y: dirtyRect.minY))
        divider.line(to: NSPoint(x: safeWidth - 0.5, y: dirtyRect.maxY))
        divider.lineWidth = 0.5
        divider.stroke()
    }
}
