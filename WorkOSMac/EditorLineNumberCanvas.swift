import AppKit

/// A narrowly bounded, non-interactive drawing surface *inside* NSTextView's
/// existing 50pt leading inset. The document remains the same native NSTextView
/// and TextKit viewport that worked in v0.8.19/v0.8.21.
///
/// NSTextView only invalidates the region containing its text glyphs during
/// some redraws. Painting line numbers in NSTextView.draw(_:) outside that dirty
/// region can silently clip them away. A dedicated 44pt child surface receives
/// its own invalidations and never covers the actual text container.
final class WorkOSLineNumberCanvas: NSView {
    private weak var editor: NSTextView?
    private let painter = WorkOSLineNumberPainter()
    private var textObserver: NSObjectProtocol?
    private var scrollObserver: NSObjectProtocol?

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    init(editor: NSTextView) {
        self.editor = editor
        super.init(frame: NSRect(x: 0, y: 0,
                                 width: WorkOSLineNumberPainter.gutterWidth,
                                 height: max(1, editor.bounds.height)))
        // The canvas follows document height, not the editor's width or the
        // NSTextContainer layout. No autoresizing in the horizontal axis.
        autoresizingMask = [.height]
        if let storage = editor.textStorage {
            textObserver = NotificationCenter.default.addObserver(
                forName: NSTextStorage.didProcessEditingNotification,
                object: storage, queue: .main) { [weak self] _ in
                    guard let self else { return }
                    if let storage = self.editor?.textStorage,
                       storage.editedMask.contains(.editedCharacters) {
                        self.painter.updateAfterEdit(in: self.editor?.string ?? "",
                                                     editedRange: storage.editedRange,
                                                     delta: storage.changeInLength)
                    }
                    self.invalidateVisibleLines()
                }
        }
    }

    required init?(coder: NSCoder) { nil }

    deinit {
        if let textObserver { NotificationCenter.default.removeObserver(textObserver) }
        if let scrollObserver { NotificationCenter.default.removeObserver(scrollObserver) }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Clicks and text selection pass through to the native text editor.
        nil
    }

    func watchScroll(in scroll: NSScrollView) {
        if let scrollObserver { NotificationCenter.default.removeObserver(scrollObserver) }
        scroll.contentView.postsBoundsChangedNotifications = true
        scrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scroll.contentView, queue: .main) { [weak self] _ in
                self?.invalidateVisibleLines()
            }
        invalidateVisibleLines()
    }

    func invalidateVisibleLines() {
        guard let editor else { return }
        // Only the visible strip is invalidated, even for very long notes.
        let viewport = editor.visibleRect
        setNeedsDisplay(NSRect(x: 0, y: max(0, viewport.minY),
                               width: bounds.width, height: max(1, viewport.height)))
    }

    // Used only by the synthetic Mac renderer smoke test.
    func visiblePlacementsForTesting() -> [(number: Int, y: CGFloat, height: CGFloat)] {
        guard let editor else { return [] }
        return painter.visiblePlacements(in: editor, rect: editor.visibleRect)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let editor else { return }
        // Both canvas and NSTextView are flipped and start at document (0,0).
        // The canvas clips painting to x=0...44; text starts at x>=50.
        painter.draw(in: editor, dirtyRect: dirtyRect)
    }
}
