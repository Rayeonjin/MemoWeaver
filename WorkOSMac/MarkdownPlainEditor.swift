import AppKit
import SwiftUI

// Deliberately separate from the stable v0.8.23 rich-text NSTextView.
// Markdown edits only plain Unicode characters. No HTML writer, live Markdown
// substitutions, slash-command interpreter, or text-storage reconstruction.
final class WorkOSMarkdownTextView: NSTextView {
    weak var slashCoordinator: MarkdownPlainEditor.Coordinator?
    // Synchronous, failure-aware attachment save owned by the active note.
    // This callback is invoked only for explicit ⌘V image paste.
    var pastePNGIntoNote: ((Data) -> String?)?
    var reportImageImportError: ((String) -> Void)?
    // Source Markdown stays ordinary NSTextStorage characters. Both visual
    // features below are paint-only: no saved attributes and no undo entries.
    private var syntaxRefreshWork: DispatchWorkItem?
    private var highlightedRange = NSRange(location: 0, length: 0)
    private var syntaxRefreshAfterIME = false
    // Repaint only the previous/new caret row on movement. Invalidating the
    // entire visible editor for every keystroke wastes TextKit draw time.
    private var previousCaretRow: NSRect?
    private var pendingCaretRedraw: DispatchWorkItem?
    var syntaxColorsEnabled = true {
        didSet {
            if syntaxColorsEnabled != oldValue { scheduleSyntaxRefresh() }
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        // Dynamic label colors and temporary syntax colors must be repainted
        // after the system changes appearance; source NSTextStorage is untouched.
        scheduleSyntaxRefresh()
        setNeedsDisplay(visibleRect)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { setNeedsDisplay(visibleRect) }
    }

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        // A native divider/window drag can invalidate this view many times per
        // second. The caret-row tint is purely decorative: skip its TextKit
        // lookup while the pointer is down; never skip the actual text draw.
        guard NSEvent.pressedMouseButtons == 0,
              !inLiveResize,
              selectedRange().length == 0,
              let line = caretVisualLineRect(), line.intersects(rect) else { return }
        // Draw only to the right of the existing line-number canvas (44pt).
        // Never modify NSTextContainer insets, fragment heights or fonts.
        let left = max(WorkOSLineNumberPainter.gutterWidth + 2,
                       textContainerOrigin.x - 3)
        let highlight = NSRect(x: left, y: line.minY,
                               width: max(0, bounds.width - left - 6),
                               height: line.height)
        guard !highlight.isEmpty else { return }
        NSColor.controlAccentColor.withAlphaComponent(0.09).setFill()
        NSBezierPath(rect: highlight.intersection(rect)).fill()
    }

    private func caretVisualLineRect() -> NSRect? {
        guard let manager = layoutManager, let container = textContainer else { return nil }
        let size = (string as NSString).length
        let caret = min(selectedRange().location, size)
        // Only the caret character needs a layout fragment. Ensuring the
        // entire text container on every paint is expensive for long notes.
        if size > 0 {
            manager.ensureLayout(forCharacterRange: NSRange(location: min(caret, size - 1), length: 1))
        }
        let local: NSRect
        if (size == 0 || (caret == size && string.hasSuffix("\n"))),
           manager.extraLineFragmentTextContainer === container,
           !manager.extraLineFragmentRect.isEmpty {
            // Last empty line has no glyph; do not ask TextKit for an invalid
            // glyph index. This preserves the v0.9.5 blank-line baseline.
            local = manager.extraLineFragmentRect
        } else if manager.numberOfGlyphs > 0 {
            let glyph = caret < size
                ? manager.glyphIndexForCharacter(at: caret)
                : manager.numberOfGlyphs - 1
            local = manager.lineFragmentRect(forGlyphAt: min(glyph, manager.numberOfGlyphs - 1),
                                             effectiveRange: nil)
        } else {
            let font = self.font ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            local = NSRect(x: 0, y: 0, width: 1,
                           height: manager.defaultLineHeight(for: font))
        }
        return local.offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
    }

    func caretDidMove() {
        // Keep TextKit fragment layout OUT of the synchronous key-down path.
        // Several selection notifications can arrive for a single IME edit;
        // coalesce them into one paint-only pass on the next main-loop turn.
        pendingCaretRedraw?.cancel()
        let redraw = DispatchWorkItem { [weak self] in self?.redrawCaretRows() }
        pendingCaretRedraw = redraw
        DispatchQueue.main.async(execute: redraw)
        if syntaxRefreshAfterIME && !hasMarkedText() { scheduleSyntaxRefresh() }
    }

    private func redrawCaretRows() {
        pendingCaretRedraw = nil
        let next = selectedRange().length == 0 ? caretVisualLineRect() : nil
        let before = previousCaretRow
        previousCaretRow = next
        if let before, before.intersects(visibleRect) {
            setNeedsDisplay(before.insetBy(dx: -2, dy: -2))
        }
        if let next, next.intersects(visibleRect), next != before {
            setNeedsDisplay(next.insetBy(dx: -2, dy: -2))
        }
    }

    func scheduleSyntaxRefresh() {
        // Never recolor marked text during Korean IME composition. Heavy
        // Markdown regex work is delayed and restricted to the visible page.
        if hasMarkedText() { syntaxRefreshAfterIME = true; return }
        syntaxRefreshWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.hasMarkedText() else {
                self?.syntaxRefreshAfterIME = true
                return
            }
            // Dragging a native splitter/window should have priority over
            // paint-only Markdown syntax analysis. Retry after mouse release.
            if self.inLiveResize || NSEvent.pressedMouseButtons != 0 {
                self.scheduleSyntaxRefresh()
                return
            }
            self.syntaxRefreshAfterIME = false
            self.applySyntaxColors()
        }
        syntaxRefreshWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    private func applySyntaxColors() {
        guard let manager = layoutManager, let container = textContainer else { return }
        let text = string as NSString
        let length = text.length
        // Clear only last viewport, never all 10,000 lines on each keystroke.
        let former = NSIntersectionRange(highlightedRange, NSRange(location: 0, length: length))
        if former.length > 0 {
            manager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: former)
        }
        highlightedRange = NSRange(location: 0, length: 0)
        if syntaxColorsEnabled && length > 0 {
            let origin = textContainerOrigin
            let rectangle = visibleRect.offsetBy(dx: -origin.x, dy: -origin.y)
            let glyphs = manager.glyphRange(forBoundingRect: rectangle, in: container)
            let visible = manager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
            guard visible.location != NSNotFound else {
                // No laid-out glyph intersects this viewport: do not pass
                // NSNotFound through NSMaxRange (which can overflow).
                setNeedsDisplay(visibleRect)
                return
            }
            let start = min(length, visible.location)
            let end = min(length, max(start, NSMaxRange(visible)))
            // A short context window covers most nearby fences without
            // scanning/coloring a full old scratchpad on every input.
            let contextual = max(0, start - 900)
            let firstLine = text.lineRange(for: NSRange(location: contextual, length: 0)).location
            let lastLine = text.lineRange(for: NSRange(location: max(0, end - 1), length: 0))
            let windowEnd = min(length, NSMaxRange(lastLine))
            if windowEnd > firstLine {
                let window = NSRange(location: firstLine, length: windowEnd - firstLine)
                let snippet = text.substring(with: window)
                for span in MarkdownEditorHighlightCore.spans(in: snippet) {
                    let absolute = NSRange(location: window.location + span.range.location,
                                           length: span.range.length)
                    guard NSMaxRange(absolute) <= length else { continue }
                    manager.addTemporaryAttribute(.foregroundColor,
                        value: syntaxColor(span.kind), forCharacterRange: absolute)
                }
                highlightedRange = window
            }
        }
        // Explicit display invalidation preserves the v0.9.10 fix for
        // text that appears missing until a double click or pane resize.
        let dirty = NSUnionRange(former, highlightedRange)
        if dirty.length > 0 { manager.invalidateDisplay(forCharacterRange: dirty) }
        setNeedsDisplay(visibleRect)
    }

    private func syntaxColor(_ kind: MarkdownEditorHighlightCore.Kind) -> NSColor {
        switch kind {
        case .heading: return .systemBlue
        case .listMarker, .checkbox: return .systemOrange
        case .quoteMarker: return .systemGreen
        case .fence, .mathDelimiter: return .systemPurple
        case .inlineCode: return .systemBrown
        case .emphasisMarker: return .secondaryLabelColor
        case .link: return .systemTeal
        }
    }
    override func keyDown(with event: NSEvent) {
        if !hasMarkedText(), slashCoordinator?.handleSlashKey(event, in: self) == true { return }
        // Never intercept keystrokes while the Korean IME is composing text.
        // Tab indents the logical source line, not the caret's character offset.
        if !hasMarkedText() && !event.modifierFlags.contains(.command) &&
            !event.modifierFlags.contains(.control) && !event.modifierFlags.contains(.option) {
            if event.keyCode == 48 {
                changeIndent(outdent: event.modifierFlags.contains(.shift))
                return
            }
            if event.keyCode == 36 && !event.modifierFlags.contains(.shift), continueList() {
                return
            }
        }
        super.keyDown(with: event)
    }

    private func changeIndent(outdent: Bool) {
        guard let change = MarkdownIndentCore.change(in: string, selection: selectedRange(),
                                                     outdent: outdent) else { return }
        insertText(change.replacement, replacementRange: change.range)
        setSelectedRange(change.selection)
    }

    private func continueList() -> Bool {
        let selection = selectedRange()
        guard selection.length == 0 else { return false }
        let ns = string as NSString
        let location = min(selection.location, ns.length)
        let lineRange = ns.lineRange(for: NSRange(location: location, length: 0))
        let line = ns.substring(with: lineRange).trimmingCharacters(in: .newlines)
        // Lists are source text. Leave Enter alone in code fences and math.
        guard MarkdownContextCore.context(in: string, utf16Offset: location) == .normal,
              let next = MarkdownIndentCore.nextListPrefix(after: line),
              location == lineRange.location + (line as NSString).length else { return false }
        if next.isEmpty {
            // Return on an empty list marker exits the list, as in VS Code.
            insertText("", replacementRange: NSRange(location: lineRange.location,
                                                       length: (line as NSString).length))
        } else {
            insertText("\n" + next, replacementRange: selection)
        }
        return true
    }

    private func plainClipboardText() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    // Both macOS Edit > Paste and Command-V route here when the text editor is
    // first responder. Do not infer "spreadsheet" from an advertised UTI: image
    // providers may advertise placeholder TSV with no actual table cells.
    // NSTextView normally validates Paste against *plain-text* formats when
    // isRichText/importsGraphics are false. Image-only screenshots can therefore
    // leave the system Edit > Paste item disabled, so Command-V never reaches
    // our paste(_:) override. Advertise image readability for menu validation,
    // and explicitly enable this one action when the clipboard has an image.
    // The editor still stores only Markdown text, NEVER NSTextAttachments.
    override var readablePasteboardTypes: [NSPasteboard.PasteboardType] {
        let base = super.readablePasteboardTypes
        let imageTypes: [NSPasteboard.PasteboardType] = [
            .png, .tiff, .fileURL, NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("public.heic"),
            NSPasteboard.PasteboardType("public.heif")
        ]
        return base + imageTypes.filter { !base.contains($0) }
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(paste(_:)), isEditable,
           MemoWeaverEditorImageInput.containsImage(NSPasteboard.general) {
            return true
        }
        return super.validateMenuItem(menuItem)
    }

    override func paste(_ sender: Any?) {
        let board = NSPasteboard.general
        let plain = plainClipboardText()
        let tabularTypes = ["public.tab-separated-values-text", "public.utf8-tab-separated-values-text",
                            "NSTabularTextPboardType", "text/tab-separated-values"]
        let tabular = tabularTypes.compactMap {
            board.string(forType: NSPasteboard.PasteboardType($0))
        }.first(where: { WorkOSPasteTable.tabDelimitedText(from: $0) != nil })
        let htmlTypes = ["public.html", "text/html", "HTML"]
        let html = htmlTypes.compactMap { kind -> String? in
            let type = NSPasteboard.PasteboardType(kind)
            if let value = board.string(forType: type) { return value }
            if let data = board.data(forType: type) { return String(data: data, encoding: .utf8) }
            return nil
        }.first(where: { $0.range(of: "<table", options: .caseInsensitive) != nil &&
                          $0.range(of: "</table", options: .caseInsensitive) != nil })
        let hasActualTable = MemoWeaverPasteSelection.containsActualTable(
            tabular: tabular, html: html, plain: plain)

        if hasMarkedText() && MemoWeaverEditorImageInput.containsImage(board) {
            reportImageImportError?("한글 조합 입력을 완료한 다음 이미지를 붙여넣으세요.")
            return
        }
        if !hasActualTable {
            // Every clipboard image uses exactly the same atomic storage path
            // as the already-working Finder image drag. Never paste a path.
            switch MemoWeaverEditorImageInput.read(board) {
            case .png(let png):
                _ = insertAttachment(png, at: nil)
                return
            case .failed(let message):
                reportImageImportError?(message)
                return
            case .notImage: break
            }
        }
        let tableCandidate = WorkOSPasteTable.preferredText(plain: plain,
                                                             tabular: tabular, html: html)
        let converted = hasActualTable
            ? tableCandidate.flatMap(MarkdownPasteCore.markdownTable(from:)) : nil
        guard let result = converted ?? plain else {
            // Previously the unsupported/empty clipboard path silently did
            // nothing. Surface an actionable error only for a real paste.
            reportImageImportError?("지원되는 이미지나 텍스트를 찾지 못했습니다. 클립보드 형식: " +
                                    MemoWeaverEditorImageInput.typeSummary(board))
            return
        }
        insertText(result, replacementRange: selectedRange())
    }

    // Explicit native fallback also makes it possible to distinguish an
    // image-decoding problem from an AppKit Command-V responder-chain problem.
    // This does NOT replace normal paste and never alters the Excel paste path.
    @objc func pasteClipboardImage(_ sender: Any?) {
        let board = NSPasteboard.general
        guard !hasMarkedText() else {
            reportImageImportError?("한글 조합 입력을 완료한 다음 이미지를 붙여넣으세요.")
            return
        }
        switch MemoWeaverEditorImageInput.read(board) {
        case .png(let png): _ = insertAttachment(png, at: nil)
        case .failed(let message): reportImageImportError?(message)
        case .notImage:
            reportImageImportError?("클립보드에 지원되는 이미지가 없습니다. 형식: " +
                                    MemoWeaverEditorImageInput.typeSummary(board))
        }
    }

    private func insertAttachment(_ png: Data, at dropLocation: NSPoint?) -> Bool {
        guard let handler = pastePNGIntoNote else {
            reportImageImportError?("현재 메모가 없어 이미지를 저장할 수 없습니다.")
            return false
        }
        guard isEditable else {
            reportImageImportError?("읽기 전용 메모에는 이미지를 추가할 수 없습니다.")
            return false
        }
        guard !hasMarkedText() else {
            reportImageImportError?("한글 조합 입력을 완료한 다음 이미지를 넣어 주세요.")
            return false
        }
        guard let markdown = handler(png) else { return false }
        var replacement = selectedRange()
        if let dropLocation, let manager = layoutManager, let container = textContainer {
            let point = convert(dropLocation, from: nil)
            let local = NSPoint(x: point.x - textContainerOrigin.x,
                                y: point.y - textContainerOrigin.y)
            let position = manager.characterIndex(for: local, in: container,
                                                  fractionOfDistanceBetweenInsertionPoints: nil)
            replacement = NSRange(location: min(position, (string as NSString).length), length: 0)
        }
        insertText(markdown, replacementRange: replacement)
        return true
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if MemoWeaverEditorImageInput.containsImage(sender.draggingPasteboard) { return .copy }
        return super.draggingEntered(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if MemoWeaverEditorImageInput.containsImage(sender.draggingPasteboard) { return .copy }
        return super.draggingUpdated(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let board = sender.draggingPasteboard
        switch MemoWeaverEditorImageInput.read(board) {
        case .png(let png):
            _ = insertAttachment(png, at: sender.draggingLocation)
            return true // Consume even on error: never insert a path instead.
        case .failed(let message):
            reportImageImportError?(message)
            return true
        case .notImage:
            return super.performDragOperation(sender)
        }
    }

    override func pasteAsPlainText(_ sender: Any?) {
        if let plain = plainClipboardText() { insertText(plain, replacementRange: selectedRange()) }
    }

    // The old rich editor offered a post-paste "convert table to plain text"
    // action. The unified Markdown source editor had no equivalent. Context
    // actions operate only on the validated table at the caret/selection.
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        guard !hasMarkedText(),
              MarkdownTableTextCore.conversion(in: string, selection: selectedRange()) != nil
        else { return menu }
        menu.addItem(.separator())
        let convert = NSMenuItem(title: "Markdown 표 → 탭 구분 텍스트로 변환",
                                 action: #selector(convertMarkdownTableToTSV(_:)), keyEquivalent: "")
        convert.target = self
        menu.addItem(convert)
        let copy = NSMenuItem(title: "Markdown 표를 텍스트로 복사 (원본 유지)",
                              action: #selector(copyMarkdownTableAsTSV(_:)), keyEquivalent: "")
        copy.target = self
        menu.addItem(copy)
        return menu
    }

    @objc func convertMarkdownTableToTSV(_ sender: Any?) {
        guard !hasMarkedText(),
              let result = MarkdownTableTextCore.conversion(in: string, selection: selectedRange())
        else { return }
        // NSTextView's ordinary edit path supplies textDidChange, autosave,
        // selection updates and native undo. Never rewrite textStorage directly.
        insertText(result.tsv, replacementRange: result.range)
        let caret = result.range.location + (result.tsv as NSString).length
        setSelectedRange(NSRange(location: caret, length: 0))
        scrollRangeToVisible(selectedRange())
    }

    @objc func copyMarkdownTableAsTSV(_ sender: Any?) {
        guard !hasMarkedText(),
              let result = MarkdownTableTextCore.conversion(in: string, selection: selectedRange())
        else { return }
        let clipboard = NSPasteboard.general
        clipboard.clearContents()
        _ = clipboard.setString(result.tsv, forType: .string)
    }
}

struct MarkdownPlainEditor: NSViewRepresentable {
    let initialText: String
    let insertRequest: MarkdownInsertRequest?
    let fontSize: Double
    let syntaxColorsEnabled: Bool
    let autoFocus: Bool
    let focusLine: Int
    let focusRequestID: UUID
    let restoreCaretOffset: Int?
    let onImagePaste: (Data) -> String?
    let onImageImportError: (String) -> Void
    let onChange: (String) -> Void
    let onTemplateInsertion: () -> Void
    let onContextChange: (MarkdownEditingContext) -> Void
    let onCaretLineChange: (Int) -> Void
    let onCaretStatusChange: (Int, Int, Int, Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange, onTemplateInsertion: onTemplateInsertion,
                    onContextChange: onContextChange,
                    onCaretLineChange: onCaretLineChange,
                    onCaretStatusChange: onCaretStatusChange)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = WorkOSTextWrappingScrollView()
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.horizontalScrollElasticity = .none
        scroll.autohidesScrollers = true
        scroll.drawsBackground = true
        scroll.backgroundColor = .textBackgroundColor
        let editor = WorkOSMarkdownTextView(frame: NSRect(x: 0, y: 0, width: 580, height: 600))
        editor.isRichText = false
        editor.isEditable = true
        editor.isSelectable = true
        editor.allowsUndo = true
        editor.importsGraphics = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticDataDetectionEnabled = false
        editor.usesFindPanel = true
        editor.font = NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
        editor.textColor = .labelColor
        editor.syntaxColorsEnabled = syntaxColorsEnabled
        editor.pastePNGIntoNote = onImagePaste
        editor.reportImageImportError = onImageImportError
        editor.registerForDraggedTypes([.fileURL, .png, .tiff,
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("public.heic")])
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.lineBreakMode = .byWordWrapping
        editor.defaultParagraphStyle = paragraph
        editor.typingAttributes = [
            .font: NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
        editor.textContainerInset = NSSize(width: 50, height: 18)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.minSize = NSSize(width: 0, height: 0)
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                height: CGFloat.greatestFiniteMagnitude)
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.heightTracksTextView = false
        editor.delegate = context.coordinator
        editor.slashCoordinator = context.coordinator
        editor.string = initialText
        // Markdown is plain source, not attributed user content. Explicitly
        // normalize display-only attributes once on initial load so hard LF,
        // whitespace-only lines and letters share font/paragraph metrics.
        // Never rewrite the string, persisted note or undo history on typing.
        if let storage = editor.textStorage, storage.length > 0 {
            storage.setAttributes(editor.typingAttributes,
                                  range: NSRange(location: 0, length: storage.length))
        }
        context.coordinator.loadSource(initialText)
        context.coordinator.lastFocusRequestID = focusRequestID
        if focusLine > 0 {
            jumpToSourceLine(focusLine, in: editor)
        } else if let saved = restoreCaretOffset {
            editor.setSelectedRange(NSRange(location: max(0, min(saved, (editor.string as NSString).length)), length: 0))
        }
        scroll.documentView = editor
        scroll.fitDocumentToViewport()
        // NSTextView does not guarantee textViewDidChangeSelection on mount.
        // A reopened note with its caret inside a block must show the palette.
        // Publish after SwiftUI finishes mounting NSViewRepresentable.
        let coordinator = context.coordinator
        DispatchQueue.main.async { [weak editor, weak coordinator] in
            guard let editor, let coordinator else { return }
            coordinator.reportInitialCaret(in: editor)
        }
        if focusLine > 0 || restoreCaretOffset != nil {
            DispatchQueue.main.async { [weak editor] in
                guard let editor else { return }
                editor.scrollRangeToVisible(editor.selectedRange())
            }
        }
        // Reuse the line-number canvas that is working in v0.8.23; never
        // change the document width/scroll hierarchy to draw the gutter.
        let canvas = WorkOSLineNumberCanvas(editor: editor)
        editor.addSubview(canvas)
        canvas.watchScroll(in: scroll)
        context.coordinator.watchEditorScroll(scroll, editor: editor)
        editor.scheduleSyntaxRefresh()
        if autoFocus {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                if let window = scroll.window { window.makeFirstResponder(editor) }
            }
        }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        (scroll as? WorkOSTextWrappingScrollView)?.fitDocumentToViewport()
        context.coordinator.onChange = onChange
        context.coordinator.onTemplateInsertion = onTemplateInsertion
        context.coordinator.onContextChange = onContextChange
        context.coordinator.onCaretLineChange = onCaretLineChange
        context.coordinator.onCaretStatusChange = onCaretStatusChange
        guard let editor = scroll.documentView as? NSTextView else { return }
        // Switching the syntax-color safety option only affects temporary
        // layout attributes, not saved Markdown or the undo history.
        (editor as? WorkOSMarkdownTextView)?.syntaxColorsEnabled = syntaxColorsEnabled
        (editor as? WorkOSMarkdownTextView)?.pastePNGIntoNote = onImagePaste
        (editor as? WorkOSMarkdownTextView)?.reportImageImportError = onImageImportError
        let targetFont = NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
        if abs((editor.font?.pointSize ?? 0) - targetFont.pointSize) > 0.1 {
            editor.font = targetFont // display-only; string, selection and undo stay intact
            (editor as? WorkOSMarkdownTextView)?.scheduleSyntaxRefresh()
            // Font changes reflow TextKit without a text-storage notification.
            // Refresh the independent, read-only gutter after the re-layout.
            if let layoutManager = editor.layoutManager, let textContainer = editor.textContainer {
                layoutManager.ensureLayout(for: textContainer)
            }
            editor.subviews.compactMap { $0 as? WorkOSLineNumberCanvas }
                .forEach { $0.invalidateVisibleLines() }
        }
        if focusLine > 0 && context.coordinator.lastFocusRequestID != focusRequestID {
            context.coordinator.lastFocusRequestID = focusRequestID
            jumpToSourceLine(focusLine, in: editor)
        }
        if let insertRequest, context.coordinator.lastRequestID != insertRequest.id {
            context.coordinator.lastRequestID = insertRequest.id
            let selected = editor.selectedRange()
            let ns = editor.string as NSString
            let selectedText = ns.substring(with: NSIntersectionRange(selected, NSRange(location: 0, length: ns.length)))
            let prepared = MarkdownAssistInsertionCore.prepare(
                source: insertRequest.source, caretBack: insertRequest.caretBack,
                selectedText: selectedText, wrapsSelection: insertRequest.wrapsSelection)
            let before = selected.location > 0 && selected.location <= ns.length
                ? ns.substring(with: NSRange(location: selected.location-1, length: 1)) : ""
            let lineStart = ns.lineRange(for: NSRange(location: min(selected.location, ns.length), length: 0)).location
            let beforeInLine = ns.substring(with: NSRange(location: lineStart, length: max(0, selected.location-lineStart)))
            let prefix: String
            if insertRequest.inlineSnippet {
                // Mermaid multi-line snippets must start on their own line;
                // fractions, operators and simple nodes stay at the caret.
                prefix = insertRequest.beginsOnNewLine &&
                    !beforeInLine.trimmingCharacters(in: .whitespaces).isEmpty ? "\n" : ""
            } else {
                prefix = before.isEmpty || before == "\n" ? "" : "\n\n"
            }
            let suffix = insertRequest.beginsOnNewLine && !prepared.source.hasSuffix("\n") ? "\n" : ""
            let source = prefix + prepared.source + suffix
            editor.insertText(source, replacementRange: selected)
            // The helper's caret is relative to the *template*, not the
            // appended newline. Preserve any selected text wrapped by math.
            let position = selected.location + (prefix as NSString).length +
                (prepared.source as NSString).length - prepared.caretBack
            editor.setSelectedRange(NSRange(location: max(0, position), length: 0))
            editor.scrollRangeToVisible(editor.selectedRange())
            // Insertion can replace the current line with a multi-line math
            // or Mermaid block while the caret remains on its prior line
            // index. Recheck AFTER the replacement and final caret position.
            // Defer the SwiftUI state callback until this NSViewRepresentable
            // update ends; the caret and storage now represent the final
            // inserted block, not the intermediate textDidChange position.
            let coordinator = context.coordinator
            DispatchQueue.main.async { [weak editor, weak coordinator] in
                guard let editor, let coordinator else { return }
                // Toolbar/menu actions can temporarily steal first responder.
                // Restore the editor BEFORE publishing the final block
                // context, so the first insertion activates its tools.
                editor.window?.makeFirstResponder(editor)
                coordinator.forceRefreshContext(in: editor)
            }
        }
    }

    private func jumpToSourceLine(_ line: Int, in editor: NSTextView) {
        guard line > 0 else { return }
        let starts = EditorLineNumberRules.lineStarts(in: editor.string)
        let index = min(starts.count - 1, line - 1)
        guard index >= 0 else { return }
        editor.setSelectedRange(NSRange(location: starts[index], length: 0))
        editor.scrollRangeToVisible(editor.selectedRange())
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var onChange: (String) -> Void
        var onTemplateInsertion: () -> Void
        var onContextChange: (MarkdownEditingContext) -> Void
        var onCaretLineChange: (Int) -> Void
        var onCaretStatusChange: (Int, Int, Int, Int) -> Void
        // NSTextView's delegate callback is not guaranteed for every
        // programmatic insertText (toolbar and slash palette). Keep the last
        // published source so the explicit post-insertion check cannot
        // duplicate save/preview work when textDidChange has already fired.
        private var lastPublishedText = ""
        private var lastContext: MarkdownEditingContext = .normal
        private var lastContextLine = -1
        private var lastContextFenceHint = ""
        private var cachedLineStarts: [Int] = [0]
        private var lastReportedLine = 0
        private var lastReportedColumn = 0
        private var lastReportedTotalLines = 0
        private var lastReportedLineForStatus = 0
        private var lastReportedOffset = -1
        var lastRequestID: UUID?
        var lastFocusRequestID: UUID?
        private var syntaxScrollObserver: NSObjectProtocol?
        deinit {
            if let syntaxScrollObserver { NotificationCenter.default.removeObserver(syntaxScrollObserver) }
            if let slashMouseDownMonitor { NSEvent.removeMonitor(slashMouseDownMonitor) }
            if let slashResignObserver { NotificationCenter.default.removeObserver(slashResignObserver) }
        }
        fileprivate func watchEditorScroll(_ scroll: NSScrollView, editor: WorkOSMarkdownTextView) {
            if let syntaxScrollObserver { NotificationCenter.default.removeObserver(syntaxScrollObserver) }
            syntaxScrollObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification, object: scroll.contentView,
                queue: .main) { [weak editor] _ in editor?.scheduleSyntaxRefresh() }
        }

        private var slashPopup: NSPopover?
        private var slashHost: NSHostingController<MarkdownSlashPalette>?
        private var slashMouseDownMonitor: Any?
        private var slashResignObserver: NSObjectProtocol?
        private var slashTrigger: SlashCommandCore.Trigger?
        private var slashContext: MarkdownEditingContext = .normal
        private var slashItems: [SlashCommandCore.Item] = []
        private var slashIndex = 0
        private var suppressedSlashCaret: Int?

        /// Native NSTextView consumes keys only while the slash palette exists.
        fileprivate func handleSlashKey(_ event: NSEvent, in editor: WorkOSMarkdownTextView) -> Bool {
            guard let popup = slashPopup, popup.isShown, slashTrigger != nil else { return false }
            switch event.keyCode {
            case 53: // escape: leave the literal / untouched
                suppressedSlashCaret = editor.selectedRange().location
                closeSlash()
                return true
            case 125: // down
                if !slashItems.isEmpty { slashIndex = min(slashItems.count - 1, slashIndex + 1) }
                renderSlash(in: editor)
                return true
            case 126: // up
                slashIndex = max(0, slashIndex - 1)
                renderSlash(in: editor)
                return true
            case 36, 76: // return/enter
                if slashItems.indices.contains(slashIndex) {
                    insertSlash(slashItems[slashIndex], in: editor)
                    return true
                }
                closeSlash()
                return false
            default:
                return false
            }
        }

        private func closeSlash() {
            if let slashMouseDownMonitor {
                NSEvent.removeMonitor(slashMouseDownMonitor)
                self.slashMouseDownMonitor = nil
            }
            if let slashResignObserver {
                NotificationCenter.default.removeObserver(slashResignObserver)
                self.slashResignObserver = nil
            }
            slashPopup?.close()
            slashPopup = nil
            slashHost = nil
            slashTrigger = nil
            slashContext = .normal
            slashItems = []
            slashIndex = 0
        }

        // A non-transient popover allows mouse-down/up to reach SwiftUI Buttons.
        // Dismiss when the user clicks elsewhere, never when a row is clicked.
        private func watchSlashMouseClicks(in editor: WorkOSMarkdownTextView) {
            if let slashMouseDownMonitor { NSEvent.removeMonitor(slashMouseDownMonitor) }
            slashMouseDownMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
            ) { [weak self, weak editor] event in
                guard let self, let editor else { return event }
                // During the popover's first layout pass, AppKit may not yet
                // expose its window. Never interpret an unknown target as an
                // outside click: that could swallow the first selection.
                guard let paletteWindow = self.slashPopup?.contentViewController?.view.window,
                      let targetWindow = event.window else { return event }
                if targetWindow === paletteWindow { return event }
                // Keep the literal slash; suppress immediate reopening when
                // the outside click leaves the caret in the same trigger.
                self.suppressedSlashCaret = editor.selectedRange().location
                self.closeSlash()
                return event
            }
        }

        private func insertSlash(_ item: SlashCommandCore.Item, in editor: NSTextView) {
            guard let trigger = slashTrigger else { return }
            let source = editor.string as NSString
            // A slow popover click must never replace unrelated text if the
            // document changed while the menu was open.
            guard NSMaxRange(trigger.range) <= source.length,
                  source.substring(with: trigger.range) == "/" + trigger.query else {
                closeSlash()
                return
            }
            let lineStart = source.lineRange(for: NSRange(location: trigger.range.location, length: 0)).location
            let prefix = source.substring(with: NSRange(location: lineStart,
                                                          length: trigger.range.location - lineStart))
            let prepared = SlashCommandCore.prepare(item, contextIsNormal: slashContext == .normal,
                                                    linePrefix: prefix)
            closeSlash()
            editor.insertText(prepared.source, replacementRange: trigger.range)
            let position = trigger.range.location + (prepared.source as NSString).length - prepared.caretBack
            editor.setSelectedRange(NSRange(location: max(trigger.range.location, position), length: 0))
            editor.scrollRangeToVisible(editor.selectedRange())
            // Do not publish the temporary selection/context while the
            // slash popover is still closing. Commit in the next main turn.
            DispatchQueue.main.async { [weak self, weak editor] in
                guard let self, let editor else { return }
                editor.window?.makeFirstResponder(editor)
                self.forceRefreshContext(in: editor)
            }
        }

        private func renderSlash(in editor: WorkOSMarkdownTextView) {
            guard let slashTrigger else { return }
            let palette = MarkdownSlashPalette(query: slashTrigger.query, context: slashContext,
                                               items: slashItems, selectedIndex: slashIndex) { [weak self, weak editor] item in
                guard let self, let editor else { return }
                // Allow the native button mouse-up to complete before closing
                // the NSHostingController and replacing the trigger text.
                DispatchQueue.main.async { [weak self, weak editor] in
                    guard let self, let editor else { return }
                    self.insertSlash(item, in: editor)
                }
            }
            slashHost?.rootView = palette
            slashPopup?.contentSize = NSSize(width: 334, height: min(460, CGFloat(91 + max(1, slashItems.count) * 49)))
        }

        private func updateSlash(in editor: WorkOSMarkdownTextView) {
            // Fast path: do not reparse any Markdown for an ordinary caret move.
            guard !editor.hasMarkedText(), editor.selectedRange().length == 0,
                  let (found, activeContext) = MarkdownSlashContextCore.trigger(
                    in: editor.string, caretUTF16: editor.selectedRange().location),
                  suppressedSlashCaret != editor.selectedRange().location else {
                closeSlash()
                return
            }
            if found == slashTrigger, activeContext == slashContext,
               slashPopup?.isShown == true { return }
            slashTrigger = found
            slashContext = activeContext
            slashItems = MarkdownSlashContextCore.matches(found.query, context: activeContext)
            slashIndex = 0
            if slashPopup?.isShown == true {
                renderSlash(in: editor)
                return
            }
            let popup = NSPopover()
            // .transient can dismiss on a mouse-down before a SwiftUI row's
            // mouse-up action; we own outside-click and Escape dismissal.
            popup.behavior = .applicationDefined
            popup.animates = false
            let palette = MarkdownSlashPalette(query: found.query, context: activeContext,
                                               items: slashItems, selectedIndex: 0) { [weak self, weak editor] item in
                guard let self, let editor else { return }
                DispatchQueue.main.async { [weak self, weak editor] in
                    guard let self, let editor else { return }
                    self.insertSlash(item, in: editor)
                }
            }
            let host = NSHostingController(rootView: palette)
            popup.contentViewController = host
            popup.contentSize = NSSize(width: 334, height: min(460, CGFloat(91 + max(1, slashItems.count) * 49)))
            slashPopup = popup
            slashHost = host
            // Screen-independent anchor uses TextKit's caret line fragment.
            // It is presentation-only, and never changes editor insets or text.
            let anchor: NSRect
            if let manager = editor.layoutManager, let container = editor.textContainer,
               manager.numberOfGlyphs > 0 {
                let char = max(0, min(editor.selectedRange().location,
                                      (editor.string as NSString).length - 1))
                let glyph = min(manager.numberOfGlyphs - 1, manager.glyphIndexForCharacter(at: char))
                let box = manager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1),
                                               in: container)
                anchor = NSRect(x: box.minX + editor.textContainerOrigin.x,
                                y: box.maxY + editor.textContainerOrigin.y,
                                width: max(2, box.width), height: 3)
            } else {
                anchor = NSRect(x: editor.textContainerOrigin.x,
                                y: editor.textContainerOrigin.y + 18, width: 2, height: 3)
            }
            popup.show(relativeTo: anchor, of: editor, preferredEdge: .maxY)
            watchSlashMouseClicks(in: editor)
            slashResignObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil, queue: .main
            ) { [weak self] _ in self?.closeSlash() }
            DispatchQueue.main.async { [weak editor] in
                guard let editor else { return }
                editor.window?.makeFirstResponder(editor)
            }
        }

        init(onChange: @escaping (String) -> Void,
             onTemplateInsertion: @escaping () -> Void,
             onContextChange: @escaping (MarkdownEditingContext) -> Void,
             onCaretLineChange: @escaping (Int) -> Void,
             onCaretStatusChange: @escaping (Int, Int, Int, Int) -> Void) {
            self.onChange = onChange
            self.onTemplateInsertion = onTemplateInsertion
            self.onContextChange = onContextChange
            self.onCaretLineChange = onCaretLineChange
            self.onCaretStatusChange = onCaretStatusChange
        }
        func loadSource(_ source: String) {
            lastPublishedText = source
            cachedLineStarts = EditorLineNumberRules.lineStarts(in: source)
            lastContext = .normal
            lastContextLine = -1
            lastContextFenceHint = ""
            lastReportedLine = 0
            lastReportedColumn = 0
            lastReportedTotalLines = 0
            lastReportedLineForStatus = 0
            lastReportedOffset = -1
        }
        func reportInitialCaret(in editor: NSTextView) {
            updateContext(for: editor)
            updateCaretLine(for: editor)
        }
        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            // Reparse the Markdown block on syntax-bearing edits, but keep the
            // fast path for ordinary typing inside large notes. Multi-line
            // edits also update cachedLineStarts below, so a changed caret
            // line naturally invalidates the context cache.
            let text = editor.string as NSString
            let offset = min(editor.selectedRange().location, text.length)
            let range = text.lineRange(for: NSRange(location: offset, length: 0))
            let lineText = text.substring(with: range)
            let stripped = lineText.trimmingCharacters(in: .whitespacesAndNewlines)
            if stripped.contains("```") || stripped.contains("~~~") ||
               stripped.contains("$$") || stripped.contains(#"\["#) ||
               stripped.contains(#"\]"#) ||
               ["xychart", "pie", "gantt", "timeline", "sequenceDiagram", "flowchart", "graph"].contains(where: {
                   stripped.hasPrefix($0)
               }) {
                lastContextLine = -1
            }
            let previousLineCount = cachedLineStarts.count
            if let storage = editor.textStorage,
               storage.editedMask.contains(.editedCharacters) {
                cachedLineStarts = EditorLineNumberRules.updatedLineStarts(
                    previous: cachedLineStarts, newText: editor.string,
                    editedRange: storage.editedRange, changeInLength: storage.changeInLength)
            } else {
                cachedLineStarts = EditorLineNumberRules.lineStarts(in: editor.string)
            }
            // A multi-line template often lands the caret at the same
            // line number as before: newlines invalidate the old fence state.
            if cachedLineStarts.count != previousLineCount { lastContextLine = -1 }
            suppressedSlashCaret = nil
            (editor as? WorkOSMarkdownTextView)?.scheduleSyntaxRefresh()
            (editor as? WorkOSMarkdownTextView)?.caretDidMove()
            publishEditedTextIfNeeded(in: editor)
            updateContext(for: editor)
            updateCaretLine(for: editor)
            if let source = editor as? WorkOSMarkdownTextView { updateSlash(in: source) }
        }
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            (editor as? WorkOSMarkdownTextView)?.caretDidMove()
            updateContext(for: editor)
            updateCaretLine(for: editor)
            if let source = editor as? WorkOSMarkdownTextView { updateSlash(in: source) }
        }
        private func updateCaretLine(for editor: NSTextView) {
            let offset = min(editor.selectedRange().location, (editor.string as NSString).length)
            let lineIndex = EditorLineNumberRules.lineIndex(forUTF16Offset: offset,
                                                            starts: cachedLineStarts)
            let line = lineIndex + 1
            if line != lastReportedLine {
                lastReportedLine = line
                onCaretLineChange(line)
            }
            let column = MemoWeaverUIRules.column(in: editor.string, utf16Offset: offset,
                                                  lineStart: cachedLineStarts[lineIndex])
            let total = cachedLineStarts.count
            if column != lastReportedColumn || total != lastReportedTotalLines ||
               line != lastReportedLineForStatus || offset != lastReportedOffset {
                lastReportedOffset = offset
                lastReportedColumn = column
                lastReportedTotalLines = total
                lastReportedLineForStatus = line
                onCaretStatusChange(line, column, total, offset)
            }
        }
        private func publishEditedTextIfNeeded(in editor: NSTextView) {
            let updated = editor.string
            guard updated != lastPublishedText else { return }
            lastPublishedText = updated
            onChange(updated)
        }
        func forceRefreshContext(in editor: NSTextView) {
            // Explicitly notify the SwiftUI draft/preview after an inserted
            // Math/Mermaid/Markmap template, even if AppKit did not call the
            // text delegate. Also run after slash-palette insertion.
            publishEditedTextIfNeeded(in: editor)
            // Toolbox and slash insertion should render immediately, not
            // wait for a subsequent keystroke or the ordinary idle debounce.
            onTemplateInsertion()
            lastContextLine = -1
            lastContextFenceHint = ""
            cachedLineStarts = EditorLineNumberRules.lineStarts(in: editor.string)
            updateContext(for: editor)
            // A programmatic template may already have triggered intermediate
            // NSTextView delegate notifications, leaving SwiftUI's palette at
            // the pre-insert state. The final caret is authoritative: publish
            // it UNCONDITIONALLY after the completed insertion, even when the
            // coordinator's cached enum is already the same.
            onContextChange(lastContext)
            updateCaretLine(for: editor)
        }
        private func updateContext(for editor: NSTextView) {
            let caret = min(editor.selectedRange().location, (editor.string as NSString).length)
            let line = EditorLineNumberRules.lineIndex(forUTF16Offset: caret, starts: cachedLineStarts)
            let ns = editor.string as NSString
            let range = ns.lineRange(for: NSRange(location: caret, length: 0))
            let lineText = ns.substring(with: range)
            let hint = lineText.contains("```") || lineText.contains("~~~") || lineText.contains("$$") ? lineText : ""
            if line == lastContextLine && hint == lastContextFenceHint { return }
            lastContextLine = line
            lastContextFenceHint = hint
            let next = MarkdownContextCore.context(in: editor.string, utf16Offset: caret)
            if next != lastContext {
                lastContext = next
                onContextChange(next)
            }
        }
    }
}
