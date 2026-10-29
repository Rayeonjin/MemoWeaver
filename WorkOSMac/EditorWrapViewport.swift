import AppKit

/// The SwiftUI HSplitView changes the scroll viewport's width while the
/// NSTextView's original document frame can remain at its initial 580pt.
/// TextKit then wraps at the stale (too wide) document width and clips text.
/// Keep the native text container and native drawing; only match the text view
/// width to the clip view after an actual resize. Never recreate text storage.
final class WorkOSTextWrappingScrollView: NSScrollView {
    private var adjustingDocumentWidth = false

    override func layout() {
        super.layout()
        fitDocumentToViewport()
    }

    func fitDocumentToViewport() {
        guard !adjustingDocumentWidth,
              let editor = documentView as? NSTextView else { return }
        let viewportWidth = contentView.bounds.width
        guard viewportWidth.isFinite, viewportWidth > 1 else { return }

        if abs(editor.frame.width - viewportWidth) > 0.5 {
            adjustingDocumentWidth = true
            defer { adjustingDocumentWidth = false }
            // widthTracksTextView reflows TextKit on this one frame change.
            // Do not adjust NSTextContainer.containerSize independently: the
            // former ruler/viewport experiment caused a blank editor.
            editor.setFrameSize(NSSize(width: viewportWidth,
                                       height: max(editor.frame.height, contentView.bounds.height)))
            // Split view resizing changes visible glyph layout without editing
            // text storage. Force a visible redraw instead of waiting for a
            // selection/double-click event to bring back missing glyph tiles.
            editor.setNeedsDisplay(editor.visibleRect)
        }
        // A stale horizontal offset clips the first letters even when the
        // horizontal scrollbar is hidden. Preserve the vertical scroll offset.
        if abs(contentView.bounds.origin.x) > 0.5 {
            contentView.scroll(to: NSPoint(x: 0, y: contentView.bounds.origin.y))
            reflectScrolledClipView(contentView)
        }
    }
}
