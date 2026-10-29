import AppKit

// AppKit-only smoke with synthetic text. Tests the actual 44pt child canvas,
// not just computed line placements. No private notes are accessed.

@main
struct EditorLineNumberPaintMacSmoke {
    @MainActor static func main() {
        _ = NSApplication.shared
        let scroll = WorkOSTextWrappingScrollView(frame: NSRect(x: 0, y: 0, width: 760, height: 360))
        // Keep synthetic bitmap validation deterministic even on a dark-mode Mac.
        scroll.appearance = NSAppearance(named: .aqua)
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.horizontalScrollElasticity = .none
        // Attach to a real (never shown) AppKit window so bitmap caching can
        // produce actual backing pixels instead of an unattached placeholder.
        let syntheticWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 360),
                                       styleMask: [], backing: .buffered, defer: false)
        syntheticWindow.contentView = scroll
        let editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 580, height: 600))
        editor.isRichText = true
        editor.isEditable = true
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.minSize = .zero
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                height: CGFloat.greatestFiniteMagnitude)
        editor.autoresizingMask = [.width]
        editor.textContainerInset = NSSize(width: 50, height: 18)
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.heightTracksTextView = false
        let long = String(repeating: "English sentence with spaces and wrapping. ", count: 15)
        let sample = "Header\n\n" + long + "\n" + (1...120).map { "Line \($0)" }.joined(separator: "\n") + "\n"
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 6 // Match the editor's tall, 1.5x-style line rhythm.
        paragraph.paragraphSpacing = 9
        editor.textStorage?.setAttributedString(NSAttributedString(string: sample,
            attributes: [.font: NSFont.systemFont(ofSize: 17),
                         .foregroundColor: NSColor.labelColor,
                         .paragraphStyle: paragraph]))
        scroll.documentView = editor
        let canvas = WorkOSLineNumberCanvas(editor: editor)
        editor.addSubview(canvas)
        canvas.watchScroll(in: scroll)
        canvas.appearance = NSAppearance(named: .aqua)
        editor.setSelectedRange(NSRange(location: 4, length: 0))
        let stableCount = scroll.subviews.count
        for width: CGFloat in [760, 390, 275, 570, 760] {
            scroll.setFrameSize(NSSize(width: width, height: 360))
            scroll.layoutSubtreeIfNeeded()
            scroll.fitDocumentToViewport()
            guard let manager = editor.layoutManager, let container = editor.textContainer else {
                fputs("FAIL: native TextKit missing\n", stderr); exit(1)
            }
            manager.ensureLayout(for: container)
            let placements = canvas.visiblePlacementsForTesting()
            // Baseline alignment regression: fragments include extra line
            // leading and paragraph spacing, so vertical centring was visibly
            // ~10pt below the corresponding 17pt text in real screenshots.
            let starts = EditorLineNumberRules.lineStarts(in: editor.string)
            let numberFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            for item in placements where item.number <= starts.count {
                let pos = starts[item.number - 1]
                if pos >= (editor.string as NSString).length { continue } // trailing empty line
                let next = item.number < starts.count ? starts[item.number] : (editor.string as NSString).length
                let content = (editor.string as NSString).substring(with: NSRange(location: pos, length: next-pos))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                // Blank lines use a nearby real glyph's baseline offset,
                // never the control character's shifted newline metrics.
                if content.isEmpty { continue }
                let glyph = manager.glyphIndexForCharacter(at: pos)
                let fragment = manager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
                let textBaseline = editor.textContainerOrigin.y + fragment.minY
                    + manager.location(forGlyphAt: glyph).y
                let numberBaseline = item.y + numberFont.ascender
                guard abs(numberBaseline - textBaseline) < 0.75 else {
                    fputs("FAIL: number baseline is not aligned to the actual TextKit glyph baseline\n", stderr)
                    exit(1)
                }
            }
            guard scroll.subviews.count == stableCount,
                  editor.string == sample,
                  editor.selectedRange().location == 4,
                  manager.numberOfGlyphs > 200,
                  abs(editor.frame.width - scroll.contentView.bounds.width) < 1,
                  scroll.contentView.documentView === editor,
                  syntheticWindow.contentView === scroll,
                  canvas.superview === editor,
                  canvas.frame.minX == 0,
                  canvas.bounds.width == WorkOSLineNumberPainter.gutterWidth,
                  canvas.hitTest(NSPoint(x: 8, y: 12)) == nil,
                  editor.textContainerOrigin.x > canvas.bounds.width,
                  placements.contains(where: { $0.number == 1 }),
                  placements.count == Set(placements.map(\.number)).count else {
                fputs("FAIL: split resize disrupted native text or line numbers\n", stderr); exit(1)
            }
        }
        if let manager = editor.layoutManager, let container = editor.textContainer {
            manager.ensureLayout(for: container)
            let requiredHeight = manager.usedRect(for: container).maxY + 2 * editor.textContainerInset.height
            if requiredHeight > editor.frame.height {
                editor.setFrameSize(NSSize(width: editor.frame.width, height: requiredHeight))
            }
        }
        let maximumScrollY = max(0, editor.bounds.maxY - scroll.contentView.bounds.height)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: maximumScrollY))
        scroll.reflectScrolledClipView(scroll.contentView)
        let lower = canvas.visiblePlacementsForTesting()
        guard lower.contains(where: { $0.number > 100 }),
              canvas.frame.maxY >= editor.visibleRect.maxY - 1,
              lower.count == Set(lower.map(\.number)).count,
              editor.string == sample else {
            fputs("FAIL: painted gutter did not follow vertical scroll\n", stderr); exit(1)
        }
        // Drawing inside a sibling surface has its own clipped dirty region.
        // The old inline NSTextView.draw(_:) test only checked *placements*;
        // it could PASS even when no digits appeared in the real UI.
        scroll.contentView.scroll(to: .zero)
        scroll.reflectScrolledClipView(scroll.contentView)
        canvas.invalidateVisibleLines()
        let bitmapRect = NSRect(x: 0, y: 0, width: 40, height: 90)
        guard let bitmap = canvas.bitmapImageRepForCachingDisplay(in: bitmapRect) else {
            fputs("FAIL: cannot render line number canvas into a bitmap\n", stderr); exit(1)
        }
        canvas.cacheDisplay(in: bitmapRect, to: bitmap)
        var darkPixels = 0
        // Ignore the separator on the right. In the light appearance, digits
        // are dark gray and background is near-white.
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<min(bitmap.pixelsWide, 35) {
                if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) {
                    let intensity = (color.redComponent + color.greenComponent + color.blueComponent) / 3
                    if intensity < 0.75 { darkPixels += 1 }
                }
            }
        }
        guard darkPixels > 4 else {
            fputs("FAIL: painter calculated numbers but no actual number ink rendered\n", stderr); exit(1)
        }
        print("PASS baseline-aligned gutter pixels; native wrap, resize, scroll, caret unchanged")
    }
}
