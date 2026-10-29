import AppKit

// CLT / AppKit-only layout smoke. Uses synthetic content, never the user's DB.
// Run the same document through several widths as a split pane is opened,
// dragged, and closed. Fail when line fragments extend outside the viewport.
@main
struct EditorWrapMacSmoke {
    @MainActor static func main() {
        _ = NSApplication.shared
        let scroll = WorkOSTextWrappingScrollView(frame: NSRect(x: 0, y: 0, width: 810, height: 380))
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.horizontalScrollElasticity = .none
        let editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 580, height: 600))
        editor.isRichText = true
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.minSize = .zero
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                height: CGFloat.greatestFiniteMagnitude)
        editor.autoresizingMask = [.width]
        editor.textContainerInset = NSSize(width: 22, height: 18)
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.heightTracksTextView = false
        let english = "These formats can be combined to create a campaign tailored to your project's goals, whether that's generating engagement, building greater awareness in the Korean market. "
        let sample = "[Upbit Marketing Campaign Opportunities]\n\nHi team!\n\n" +
                     String(repeating: english, count: 4) + "\n한글 English 끝"
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 5
        editor.textStorage?.setAttributedString(NSAttributedString(string: sample,
            attributes: [.font: NSFont.systemFont(ofSize: 17),
                         .foregroundColor: NSColor.labelColor,
                         .paragraphStyle: paragraph]))
        scroll.documentView = editor
        editor.setSelectedRange(NSRange(location: 5, length: 0))
        let initialText = editor.string

        var wideFragmentCount = 0
        for width: CGFloat in [810, 375, 280, 520, 810] {
            scroll.setFrameSize(NSSize(width: width, height: 380))
            scroll.layoutSubtreeIfNeeded()
            scroll.fitDocumentToViewport()
            guard let manager = editor.layoutManager,
                  let container = editor.textContainer else {
                fputs("FAIL: NSTextView has no TextKit layout objects\n", stderr); exit(1)
            }
            manager.ensureLayout(for: container)
            let expected = scroll.contentView.bounds.width
            guard expected > 1,
                  abs(editor.frame.width - expected) < 1,
                  container.containerSize.width > 1,
                  container.containerSize.width < expected + 2,
                  abs(scroll.contentView.bounds.origin.x) < 1,
                  editor.string == initialText,
                  editor.selectedRange().location == 5,
                  manager.numberOfGlyphs > 50 else {
                fputs("FAIL: resize clipped/hid the text, moved caret or mutated content\n", stderr)
                exit(1)
            }
            // A single paragraph must wrap at TextKit's CURRENT container
            // width, not at the original 580pt width or an earlier split size.
            var start = 0
            var fragments = 0
            while start < manager.numberOfGlyphs {
                var effective = NSRange(location: 0, length: 0)
                let used = manager.lineFragmentUsedRect(forGlyphAt: start, effectiveRange: &effective)
                if used.maxX > container.containerSize.width + 2.0 {
                    fputs("FAIL: glyph line exceeds the current text container\n", stderr)
                    exit(1)
                }
                let next = NSMaxRange(effective)
                guard next > start else {
                    fputs("FAIL: TextKit made no progress while laying out a line\n", stderr)
                    exit(1)
                }
                fragments += 1
                start = next
            }
            guard fragments > 4 else {
                fputs("FAIL: long paragraph did not wrap into multiple lines\n", stderr)
                exit(1)
            }
            if width == 810 { wideFragmentCount = fragments }
            if width == 280 && fragments <= wideFragmentCount {
                fputs("FAIL: narrowing the pane did not increase the wrapped line count\n", stderr)
                exit(1)
            }
        }
        print("PASS AppKit split-resize wrap, glyph visibility, content and caret stability")
    }
}
