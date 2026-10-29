import AppKit

// Real AppKit fixture with blank LF paragraphs vs space/tab-only paragraphs.
// Uses only synthetic text; checks renderer geometry without touching user data.
@main
struct EditorLineNumberWhitespaceMacSmoke {
    @MainActor static func main() {
        _ = NSApplication.shared
        for size: CGFloat in [17, 20] {
            let scroll = WorkOSTextWrappingScrollView(frame:
                NSRect(x: 0, y: 0, width: 600, height: 480))
            scroll.hasVerticalScroller = true
            scroll.hasHorizontalScroller = false
            let window = NSWindow(contentRect: scroll.frame, styleMask: [],
                                  backing: .buffered, defer: false)
            window.contentView = scroll
            let editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 550, height: 480))
            editor.isRichText = false
            editor.isVerticallyResizable = true
            editor.isHorizontallyResizable = false
            editor.minSize = .zero
            editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                    height: CGFloat.greatestFiniteMagnitude)
            editor.autoresizingMask = [.width]
            editor.textContainerInset = NSSize(width: 50, height: 18)
            let font = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
            editor.font = font
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 3
            paragraph.lineBreakMode = .byWordWrapping
            editor.defaultParagraphStyle = paragraph
            editor.typingAttributes = [.font: font, .paragraphStyle: paragraph,
                                       .foregroundColor: NSColor.labelColor]
            let source = "Alpha 한글\n\n \n    \n\t\nBeta 한글\n\n \n"
            editor.string = source
            let stored = editor.string
            // Mirror MarkdownPlainEditor initial display-only normalization.
            if let storage = editor.textStorage, storage.length > 0 {
                storage.setAttributes(editor.typingAttributes,
                                      range: NSRange(location: 0, length: storage.length))
            }
            scroll.documentView = editor
            scroll.fitDocumentToViewport()
            let canvas = WorkOSLineNumberCanvas(editor: editor)
            editor.addSubview(canvas)
            canvas.watchScroll(in: scroll)
            guard let manager = editor.layoutManager, let container = editor.textContainer else {
                fputs("FAIL: missing TextKit\n", stderr); exit(1)
            }
            manager.ensureLayout(for: container)
            let starts = EditorLineNumberRules.lineStarts(in: source)
            let placements = Dictionary(uniqueKeysWithValues:
                canvas.visiblePlacementsForTesting().map { ($0.number, $0.y) })
            let numberFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            // Same nominal TextKit font baseline for LF-only and spaces/tabs.
            // Real ink glyphs are separately checked by PaintMacSmoke.
            let expectedOffset = manager.defaultBaselineOffset(for: font)
            for row in [2, 3, 4, 5, 7, 8, 9] {
                guard let top = placements[row] else {
                    fputs("FAIL: missing LF / whitespace-only row number\n", stderr); exit(1)
                }
                let pos = starts[row-1]
                let rect: NSRect
                if pos < (source as NSString).length {
                    let glyph = manager.glyphIndexForCharacter(at: pos)
                    rect = manager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
                } else {
                    guard manager.extraLineFragmentTextContainer != nil else {
                        fputs("FAIL: missing final empty paragraph\n", stderr); exit(1)
                    }
                    rect = manager.extraLineFragmentRect
                }
                let offset = top + numberFont.ascender
                    - editor.textContainerOrigin.y - rect.minY
                guard abs(offset - expectedOffset) < 0.85 else {
                    fputs("FAIL: row \(row) LF/spaces/tab baseline \(offset), expected \(expectedOffset)\n", stderr)
                    exit(1)
                }
            }
            guard placements.count == starts.count, editor.string == stored,
                  window.contentView === scroll else {
                fputs("FAIL: layout changed source or lost row numbers\n", stderr); exit(1)
            }
        }
        print("PASS LF-only, spaces, tabs and trailing empty rows use consistent native row baselines")
    }
}
