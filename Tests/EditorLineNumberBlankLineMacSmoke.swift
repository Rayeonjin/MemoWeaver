import AppKit

// Reproduces the customer's Markdown screenshot: empty lines after $$,
// nested Korean lists, wrapped rows, and an empty trailing caret line.
// Never reads or writes real user notes.
@main
struct EditorLineNumberBlankLineMacSmoke {
    @MainActor static func main() {
        _ = NSApplication.shared
        let scroll = WorkOSTextWrappingScrollView(frame: NSRect(x: 0, y: 0, width: 550, height: 710))
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        let window = NSWindow(contentRect: scroll.frame, styleMask: [], backing: .buffered, defer: false)
        window.contentView = scroll
        let editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 510, height: 710))
        editor.isRichText = false
        editor.textContainerInset = NSSize(width: 50, height: 18)
        editor.font = NSFont.monospacedSystemFont(ofSize: 17, weight: .regular)
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 3
        style.lineBreakMode = .byWordWrapping
        editor.defaultParagraphStyle = style
        editor.typingAttributes = [.font: editor.font!, .paragraphStyle: style,
                                   .foregroundColor: NSColor.labelColor]
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.minSize = .zero
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.heightTracksTextView = false
        editor.string = "$$\nE = mc^2\n$$\n\n\n- 오늘은\n재미있니?\n  - 이거 되나?\n\n오늘은\n- 이건가\n    - 제발\n오\n되는거 같아\n정말?\n- 이건가\n  - 우와\n    - 그래\n  - 이거지\n- 응\n\n"
        // Mirror MarkdownPlainEditor.makeNSView: without this the fixture's
        // LF control glyphs can inherit default attributed-string styling
        // different from the real Markdown NSTextView. This is display-only.
        if let storage = editor.textStorage, storage.length > 0 {
            storage.setAttributes(editor.typingAttributes,
                                  range: NSRange(location: 0, length: storage.length))
        }
        scroll.documentView = editor
        scroll.fitDocumentToViewport()
        let canvas = WorkOSLineNumberCanvas(editor: editor)
        editor.addSubview(canvas)
        canvas.watchScroll(in: scroll)
        guard let manager = editor.layoutManager, let container = editor.textContainer else { exit(1) }
        manager.ensureLayout(for: container)
        let starts = EditorLineNumberRules.lineStarts(in: editor.string)
        let placements = Dictionary(uniqueKeysWithValues: canvas.visiblePlacementsForTesting().map { ($0.number, $0.y) })
        let numberFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        // Empty lines have no ink glyph to measure. The typesetter's default
        // baseline for the font is the unambiguous reference, regardless of
        // any script/font fallback in neighboring visible text lines.
        let expectedOffset = manager.defaultBaselineOffset(for: editor.font!)
        for blank in [4, 5, 9, 21, 22] {
            guard let labelY = placements[blank] else {
                fputs("FAIL: visible blank Markdown line lost its number\n", stderr); exit(1)
            }
            let position = starts[blank-1]
            let fragment: NSRect
            if position < (editor.string as NSString).length {
                let glyph = manager.glyphIndexForCharacter(at: position)
                fragment = manager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            } else {
                fragment = manager.extraLineFragmentRect
            }
            let gutterOffset = labelY + numberFont.ascender
                - editor.textContainerOrigin.y - fragment.minY
            guard abs(gutterOffset - expectedOffset) < 0.85 else {
                fputs("FAIL: blank Markdown line \(blank) baseline offset \(gutterOffset) != font baseline \(expectedOffset)\n", stderr)
                exit(1)
            }
        }
        guard placements.count == starts.count,
              editor.string.contains("오늘은"), window.contentView === scroll else {
            fputs("FAIL: Markdown gutter fixture was modified\n", stderr); exit(1)
        }
        print("PASS Markdown rows use their own native TextKit baselines; no neighbor shift")
    }
}
