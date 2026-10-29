import AppKit

// Synthetic editor regression test, macOS CLT only. Does not read user notes.
@main
struct EditorVisibleMacSmoke {
    @MainActor static func main() {
        _ = NSApplication.shared
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 650, height: 380))
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.horizontalScrollElasticity = .none
        let editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 580, height: 380))
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
        let sentence = "한글 English — pasted text is visible when the preview opens. "
        let original = String(repeating: sentence, count: 30)
        editor.textStorage?.setAttributedString(NSAttributedString(string: original,
            attributes: [.font: NSFont.systemFont(ofSize: 17),
                         .foregroundColor: NSColor.labelColor]))
        scroll.documentView = editor
        guard scroll.verticalRulerView == nil, editor.string == original else {
            fputs("FAIL: native editor lost text or added a ruler\n", stderr); exit(1)
        }
        // Uses actual TextKit glyph geometry, not just comparing view widths.
        for width: CGFloat in [650, 410, 310, 580] {
            scroll.setFrameSize(NSSize(width: width, height: 380))
            scroll.layoutSubtreeIfNeeded()
            guard let manager = editor.layoutManager, let container = editor.textContainer else {
                fputs("FAIL: TextKit not connected\n", stderr); exit(1)
            }
            manager.ensureLayout(for: container)
            guard manager.numberOfGlyphs > 50 else {
                fputs("FAIL: glyphs disappeared during resize\n", stderr); exit(1)
            }
            let first = manager.lineFragmentUsedRect(forGlyphAt: 0,
                effectiveRange: nil)
            guard first.width > 15, first.height > 5,
                  editor.string == original else {
                fputs("FAIL: missing first line / text changed during resize\n", stderr); exit(1)
            }
        }
        print("PASS AppKit native text layout retains nonempty glyphs and original content")
    }
}
