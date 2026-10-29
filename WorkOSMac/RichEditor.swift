import AppKit
import SwiftUI

enum RichDocument {
    static func attributed(from html: String, typography: EditorTypography) -> NSAttributedString {
        if html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return NSAttributedString(string: "", attributes: typography.standardTypingAttributes())
        }
        // Do not load remote media from archived/browser HTML into the editor.
        // Cocoa HTML stores deliberate text colors in CSS classes. Preserve only
        // foreground hex colors as inline styles before removing CSS/remote media.
        let safe = RichHTMLColorStyles.inlineForegroundColors(in: html)
            .replacingOccurrences(of: "(?is)<(script|style|iframe|object|svg|img|video|audio)\\b[^>]*>.*?</\\1>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "(?is)<(img|iframe|object|link|meta)\\b[^>]*>", with: "", options: .regularExpression)
        let document = "<html><head><meta charset='utf-8'></head><body>\(safe)</body></html>"
        if let data = document.data(using: .utf8),
           let result = try? NSAttributedString(data: data,
               options: [.documentType: NSAttributedString.DocumentType.html,
                         .characterEncoding: String.Encoding.utf8.rawValue],
               documentAttributes: nil) {
            let normalized = NSMutableAttributedString(attributedString: result)
            let display = NSMutableAttributedString(attributedString: EditorTypography.normalized(normalized,
                fromReferenceSize: EditorTypography.inferredBodySize(in: normalized),
                to: typography))
            // Reset only fixed neutral HTML ink to semantic system ink. User
            // colors (red/blue/etc.) survive reopen and font-size changes.
            _ = EditorInk.adapt(display, range: NSRange(location: 0, length: display.length))
            return display
        }
        return EditorTypography.normalized(NSAttributedString(string: HTMLText.plain(html),
                                  attributes: [.font: NSFont.systemFont(ofSize: 14),
                                               .foregroundColor: NSColor.labelColor]),
                                           fromReferenceSize: 14, to: typography)
    }

    static func html(from value: NSAttributedString) -> String {
        guard value.length > 0 else { return "" }
        if let data = try? value.data(
            from: NSRange(location: 0, length: value.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.html]),
            let result = String(data: data, encoding: .utf8) {
            return result
        }
        let plain = escapeHTML(value.string).replacingOccurrences(of: "\n", with: "</p><p>")
        return "<p>\(plain)</p>"
    }
}

enum WorkOSFormat: String, CaseIterable {
    case bold, italic, strikethrough, heading1, heading2, heading3, quote, bullet, numbered, checklist, code, divider, link, ink, removeSlash
    var label: String {
        switch self {
        case .bold: return "굵게"
        case .italic: return "기울임"
        case .strikethrough: return "취소선"
        case .heading1: return "큰 제목"
        case .heading2: return "중간 제목"
        case .heading3: return "작은 제목"
        case .quote: return "인용문"
        case .bullet: return "글머리표"
        case .numbered: return "번호 목록"
        case .checklist: return "할 일"
        case .code: return "인라인 코드"
        case .divider: return "구분선"
        case .link: return "링크"
        case .ink: return "글자색"
        case .removeSlash: return "입력 메뉴 닫기"
        }
    }
}

struct WorkOSFormatRequest: Equatable {
    var id = UUID()
    var action: WorkOSFormat
    var removeSlash: Bool
    var inkPreset: WorkOSInkPreset? = nil
    var inkHex: String? = nil
}

// Read the common Excel clipboard formats before AppKit consumes the paste.
// HTML is a fallback for one-column tables or producers without plain TSV.
private enum WorkOSPasteboardReader {
    static func unicodeText(from pasteboard: NSPasteboard) -> String? {
        let types: [NSPasteboard.PasteboardType] = [
            .string,
            NSPasteboard.PasteboardType("public.utf8-plain-text"),
            NSPasteboard.PasteboardType("public.utf16-external-plain-text")
        ]
        // Request the pasteboard's Unicode strings, not unlabelled raw bytes.
        // The preferred content is the one with the fewest actual U+FFFD
        // replacement characters; ties preserve native .string priority.
        return WorkOSPasteRecovery.bestPlainText(types.compactMap {
            pasteboard.string(forType: $0)
        })
    }

    static func tableText(from pasteboard: NSPasteboard) -> String? {
        let tabularTypes = ["public.tab-separated-values-text", "public.utf8-tab-separated-values-text",
                            "NSTabularTextPboardType", "text/tab-separated-values"]
        let tabular = tabularTypes.compactMap { pasteboard.string(forType: NSPasteboard.PasteboardType($0)) }
            .first(where: { WorkOSPasteTable.tabDelimitedText(from: $0) != nil })
        let htmlTypes = ["public.html", "text/html", "HTML"]
        let html = htmlTypes.compactMap { identifier -> String? in
            let type = NSPasteboard.PasteboardType(identifier)
            if let text = pasteboard.string(forType: type) { return text }
            guard let data = pasteboard.data(forType: type) else { return nil }
            return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16)
        }.first(where: { $0.range(of: "<table", options: .caseInsensitive) != nil })
        return WorkOSPasteTable.preferredText(
            plain: pasteboard.string(forType: .string), tabular: tabular, html: html)
    }
}

// Always use the native AppKit rich paste; report its completed UTF-16 range
// separately so only that region can be converted back to TSV on request.
private final class WorkOSPasteTextView: NSTextView {
    private var lineNumberCanvas: WorkOSLineNumberCanvas?

    func enableLineNumberPainting() {
        guard lineNumberCanvas == nil,
              let scroll = enclosingScrollView else { return }
        let canvas = WorkOSLineNumberCanvas(editor: self)
        // A 44pt subview only inside the existing leading 50pt text inset.
        // Unlike the earlier scroll-view overlay, it cannot cover document text.
        addSubview(canvas)
        lineNumberCanvas = canvas
        canvas.watchScroll(in: scroll)
    }

    var onBeginPaste: (() -> Void)?
    var onEndPaste: ((WorkOSPasteTextView, NSRange, Int, String?, String?) -> Void)?
    var onNextInteraction: (() -> Void)?

    override func paste(_ sender: Any?) {
        let selection = selectedRange()
        let previousLength = textStorage?.length ?? 0
        let clipboard = NSPasteboard.general
        let clipboardTable = WorkOSPasteboardReader.tableText(from: clipboard)
        let unicodePlain = WorkOSPasteboardReader.unicodeText(from: clipboard)
        let singleSelection = selectedRanges.count == 1
        onBeginPaste?()
        // Keep automatic Unicode repair in the same undo transaction as the
        // underlying native paste; Command-Z should not resurrect corrupt glyphs.
        let undo = undoManager
        undo?.beginUndoGrouping()
        defer { undo?.endUndoGrouping() }
        super.paste(sender)  // preserve Excel's rich text and table formatting
        onEndPaste?(self, singleSelection ? selection : NSRange(location: NSNotFound, length: 0),
                    previousLength, clipboardTable, unicodePlain)
    }

    override func pasteAsPlainText(_ sender: Any?) {
        let selection = selectedRange()
        let previousLength = textStorage?.length ?? 0
        let singleSelection = selectedRanges.count == 1
        onBeginPaste?()
        super.pasteAsPlainText(sender) // system Paste and Match Style (⌥⇧⌘V)
        onEndPaste?(self, singleSelection ? selection : NSRange(location: NSNotFound, length: 0),
                    previousLength, nil, nil)
    }

    override func keyDown(with event: NSEvent) {
        onNextInteraction?()
        super.keyDown(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        onNextInteraction?()
        super.mouseDown(with: event)
    }
}

enum WorkOSPasteAction {
    case keep, convert
}

struct WorkOSPasteActionRequest: Equatable {
    let id = UUID()
    let action: WorkOSPasteAction
}

struct WorkOSTableConversionRequest: Equatable {
    let id = UUID()
}

// macOS NSTextView is already a rich, editable, native canvas.
// The delegate converts completed Markdown syntax to styled NSAttributedString
// without rebuilding the editor on every autosave (caret and Korean IME stay put).
struct RichTextEditor: NSViewRepresentable {
    let initialHTML: String
    // If SwiftUI recreates this native view while changing split panes, seed it
    // with the in-memory edits rather than stale SQLite HTML (before debounce).
    var initialAttributedText: NSAttributedString? = nil
    let request: WorkOSFormatRequest?
    let fontSize: Double
    let lineHeight: Double
    var autoFocus = false
    let pasteAction: WorkOSPasteActionRequest?
    let onPasteChoiceChange: (Bool) -> Void
    let onPasteRecoveryChange: (Bool) -> Void
    let tableConversionRequest: WorkOSTableConversionRequest?
    let onTableSelectionChange: (Bool) -> Void
    let onTableConversionFailure: () -> Void
    let onSlash: () -> Void
    let onChange: (NSAttributedString) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange, onSlash: onSlash,
                    onPasteChoiceChange: onPasteChoiceChange,
                    onPasteRecoveryChange: onPasteRecoveryChange,
                    onTableSelectionChange: onTableSelectionChange,
                    onTableConversionFailure: onTableConversionFailure,
                    typography: EditorTypography(size: fontSize, lineHeight: lineHeight))
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = WorkOSTextWrappingScrollView()
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        // A narrow split pane must use its actual clip width for line layout.
        // Keep native TextKit wrapping: no ruler and no repeated containerSize
        // mutations (the combination previously hid all document glyphs).
        scroll.hasHorizontalScroller = false
        scroll.horizontalScrollElasticity = .none
        scroll.autohidesScrollers = true
        scroll.drawsBackground = true
        scroll.backgroundColor = .textBackgroundColor
        let editor = WorkOSPasteTextView(frame: NSRect(x: 0, y: 0, width: 580, height: 600))
        editor.onBeginPaste = { [weak coordinator = context.coordinator] in
            coordinator?.beginPaste()
        }
        editor.onEndPaste = { [weak coordinator = context.coordinator] editor, selection, before, clipboard, unicodePlain in
            coordinator?.finishPaste(in: editor, selection: selection, previousLength: before,
                                     clipboardText: clipboard, unicodePlain: unicodePlain)
        }
        editor.onNextInteraction = { [weak coordinator = context.coordinator] in
            coordinator?.nextInteraction()
        }
        editor.isEditable = true
        editor.isSelectable = true
        editor.isRichText = true
        editor.allowsUndo = true
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        let appearance = EditorTypography(size: fontSize, lineHeight: lineHeight)
        editor.font = appearance.bodyFont
        editor.defaultParagraphStyle = appearance.defaultParagraphStyle
        editor.typingAttributes = appearance.standardTypingAttributes()
        editor.textColor = .labelColor
        editor.textContainerInset = NSSize(width: 50, height: 18)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        // No 580pt minimum when the right-hand pane reduces editor width.
        editor.minSize = NSSize(width: 0, height: 0)
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                height: CGFloat.greatestFiniteMagnitude)
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.heightTracksTextView = false
        // Do not set a fixed containerSize; widthTracksTextView owns wrapping.
        editor.delegate = context.coordinator
        if let initialAttributedText {
            editor.textStorage?.setAttributedString(initialAttributedText)
        } else {
            editor.textStorage?.setAttributedString(RichDocument.attributed(from: initialHTML, typography: appearance))
        }
        if editor.textStorage?.length == 0 {
            editor.typingAttributes = appearance.standardTypingAttributes()
        }
        scroll.documentView = editor
        scroll.fitDocumentToViewport()
        editor.enableLineNumberPainting()
        if autoFocus {
            // Wait for SwiftUI to attach this view to its window; do not steal focus
            // after the editor has been created (e.g. while selecting other controls).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                if let window = scroll.window { window.makeFirstResponder(editor) }
            }
        }
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // Geometry only: changes no contents, selection, undo stack or IME.
        (nsView as? WorkOSTextWrappingScrollView)?.fitDocumentToViewport()
        // Updating an NSTextView from SwiftUI on autosave resets the caret and IME.
        context.coordinator.onChange = onChange
        context.coordinator.onSlash = onSlash
        context.coordinator.onPasteChoiceChange = onPasteChoiceChange
        context.coordinator.onPasteRecoveryChange = onPasteRecoveryChange
        context.coordinator.onTableSelectionChange = onTableSelectionChange
        context.coordinator.onTableConversionFailure = onTableConversionFailure
        if let editor = nsView.documentView as? NSTextView {
            context.coordinator.updateTypography(EditorTypography(size: fontSize, lineHeight: lineHeight),
                                                in: editor)
        }
        if let request, context.coordinator.lastHandledRequest != request.id {
            context.coordinator.lastHandledRequest = request.id
            context.coordinator.apply(request, in: nsView.documentView as? NSTextView)
        }
        if let pasteAction, context.coordinator.lastHandledPasteAction != pasteAction.id {
            context.coordinator.lastHandledPasteAction = pasteAction.id
            context.coordinator.applyPasteAction(pasteAction, in: nsView.documentView as? NSTextView)
        }
        if let tableConversionRequest,
           context.coordinator.lastHandledTableConversion != tableConversionRequest.id {
            context.coordinator.lastHandledTableConversion = tableConversionRequest.id
            context.coordinator.convertTableAtCaret(in: nsView.documentView as? NSTextView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private struct PasteOffer {
            let range: NSRange
            let pastedText: String
            let plainText: String
        }

        private var pasteOffer: PasteOffer?
        private var pasteGeneration = 0
        private var isPasting = false
        var onChange: (NSAttributedString) -> Void
        var onSlash: () -> Void
        var onPasteChoiceChange: (Bool) -> Void
        var onPasteRecoveryChange: (Bool) -> Void
        var onTableSelectionChange: (Bool) -> Void
        var onTableConversionFailure: () -> Void
        var lastHandledRequest: UUID?
        var lastHandledPasteAction: UUID?
        var lastHandledTableConversion: UUID?
        private var tableSelectionAvailable = false
        var typography: EditorTypography
        private var pendingTypography: EditorTypography?
        private var isConverting = false

        init(onChange: @escaping (NSAttributedString) -> Void, onSlash: @escaping () -> Void,
             onPasteChoiceChange: @escaping (Bool) -> Void,
             onPasteRecoveryChange: @escaping (Bool) -> Void,
             onTableSelectionChange: @escaping (Bool) -> Void,
             onTableConversionFailure: @escaping () -> Void,
             typography: EditorTypography) {
            self.onChange = onChange
            self.onSlash = onSlash
            self.onPasteChoiceChange = onPasteChoiceChange
            self.onPasteRecoveryChange = onPasteRecoveryChange
            self.onTableSelectionChange = onTableSelectionChange
            self.onTableConversionFailure = onTableConversionFailure
            self.typography = typography
        }

        func nextInteraction() {
            pasteGeneration += 1
            closePasteChoice()
            onPasteRecoveryChange(false)
        }

        func beginPaste() {
            pasteGeneration += 1
            closePasteChoice()
            onPasteRecoveryChange(false)
            isPasting = true
        }

        func finishPaste(in editor: NSTextView, selection: NSRange,
                         previousLength: Int, clipboardText: String?, unicodePlain: String?) {
            defer { isPasting = false }
            editor.breakUndoCoalescing()
            guard !editor.hasMarkedText(),
                  let storage = editor.textStorage,
                  let inserted = WorkOSPasteTable.insertedRange(selection: selection,
                      previousLength: previousLength, currentLength: storage.length) else {
                refreshTableSelection(in: editor)
                return
            }
            let pastedText = (storage.string as NSString).substring(with: inserted)
            if let repaired = WorkOSPasteRecovery.replacementText(rich: pastedText, unicodePlain: unicodePlain) {
                // Prefer a lossless Unicode source if the HTML/RTF text inserted
                // by AppKit contains actual replacement glyphs. Formatting is
                // sacrificed only in this specific corrupted-import case.
                let replacement = NSAttributedString(string: repaired,
                    attributes: typography.standardTypingAttributes())
                isConverting = true
                editor.insertText(replacement, replacementRange: inserted)
                isConverting = false
                onPasteRecoveryChange(true)
                refreshTableSelection(in: editor)
                if let updated = editor.textStorage?.copy() as? NSAttributedString { onChange(updated) }
                return
            }
            // Standardize external Times/serif and tiny HTML fonts immediately;
            // preserve the table blocks, content characters, links, bold and ink.
            let changedFont = WorkOSPastedTypography.normalize(in: storage,
                range: inserted, typography: typography)
            let changedInk = EditorInk.adapt(storage, range: inserted)
            if (changedFont || changedInk),
               let updated = storage.copy() as? NSAttributedString { onChange(updated) }
            refreshTableSelection(in: editor)
            guard let plain = clipboardText else { return }
            let updatedText = (storage.string as NSString).substring(with: inserted)
            let offer = PasteOffer(range: inserted, pastedText: updatedText, plainText: plain)
            let generation = pasteGeneration
            // Defer publication until the Command-V event has unwound. Some
            // NSTextView/Excel combinations dispatch an extra change notification
            // during paste; a transient NSPopover used to disappear immediately.
            DispatchQueue.main.async { [weak self, weak editor] in
                guard let self, let editor, self.pasteGeneration == generation,
                      let current = editor.textStorage,
                      WorkOSPasteTable.stillMatches(document: current.string,
                                                    range: offer.range,
                                                    pastedText: offer.pastedText) else { return }
                self.pasteOffer = offer
                self.onPasteChoiceChange(true)
            }
        }

        func closePasteChoice(report: Bool = true) {
            guard pasteOffer != nil else { return }
            pasteOffer = nil
            if report { onPasteChoiceChange(false) }
        }

        func applyPasteAction(_ request: WorkOSPasteActionRequest, in editor: NSTextView?) {
            // The SwiftUI action already hides the inline choice; do not update
            // SwiftUI state synchronously from updateNSView.
            guard let editor else { closePasteChoice(report: false); return }
            switch request.action {
            case .keep: closePasteChoice(report: false)
            case .convert: convertPendingPaste(in: editor)
            }
        }

        private func convertPendingPaste(in editor: NSTextView) {
            defer { closePasteChoice(report: false) }
            guard let offer = pasteOffer,
                  !editor.hasMarkedText(),
                  let storage = editor.textStorage,
                  WorkOSPasteTable.stillMatches(document: storage.string,
                                               range: offer.range,
                                               pastedText: offer.pastedText) else { return }
            let replacement = NSAttributedString(string: offer.plainText,
                attributes: typography.standardTypingAttributes())
            editor.breakUndoCoalescing()
            // NSTextView.insertText participates in AppKit's native Undo/Redo.
            // A direct NSTextStorage replacement can bypass undo registration.
            isConverting = true
            editor.insertText(replacement, replacementRange: offer.range)
            isConverting = false
            let affected = NSRange(location: offer.range.location, length: replacement.length)
            guard let updatedStorage = editor.textStorage,
                  WorkOSPasteTable.stillMatches(document: updatedStorage.string,
                      range: affected, pastedText: offer.plainText) else { return }
            let caret = NSRange(location: NSMaxRange(affected), length: 0)
            editor.setSelectedRange(caret)
            editor.breakUndoCoalescing()
            editor.scrollRangeToVisible(caret)
            editor.window?.makeFirstResponder(editor)
            if let rich = updatedStorage.copy() as? NSAttributedString { onChange(rich) }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            refreshTableSelection(in: editor)
        }

        private func refreshTableSelection(in editor: NSTextView) {
            let available = !editor.hasMarkedText()
                && editor.textStorage.map {
                    WorkOSNativeTableConversion.cursorIsInsideTable(in: $0,
                        selection: editor.selectedRange())
                } == true
            guard tableSelectionAvailable != available else { return }
            tableSelectionAvailable = available
            // NSTextView delegate callbacks can run while SwiftUI is updating.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.tableSelectionAvailable == available else { return }
                self.onTableSelectionChange(available)
            }
        }

        func convertTableAtCaret(in editor: NSTextView?) {
            // The button moves focus away from NSTextView, but its caret is
            // retained. Resolve the table anew at click time, not at paste time.
            guard let editor, editor.isEditable, !editor.hasMarkedText(),
                  let storage = editor.textStorage,
                  let offer = WorkOSNativeTableConversion.offer(in: storage,
                      selection: editor.selectedRange()) else {
                DispatchQueue.main.async { [weak self] in self?.onTableConversionFailure() }
                return
            }
            closePasteChoice(report: false)
            let replacement = NSAttributedString(string: offer.plainText,
                attributes: typography.standardTypingAttributes())
            editor.breakUndoCoalescing()
            isConverting = true
            // insertText registers its edit with NSTextView's Undo manager.
            // Replacing storage directly would bypass a reliable Command-Z.
            editor.insertText(replacement, replacementRange: offer.range)
            isConverting = false
            let converted = NSRange(location: offer.range.location, length: replacement.length)
            guard let updated = editor.textStorage,
                  WorkOSPasteTable.stillMatches(document: updated.string,
                      range: converted, pastedText: offer.plainText) else {
                DispatchQueue.main.async { [weak self] in self?.onTableConversionFailure() }
                refreshTableSelection(in: editor)
                return
            }
            let caret = NSRange(location: NSMaxRange(converted), length: 0)
            editor.setSelectedRange(caret)
            editor.scrollRangeToVisible(caret)
            editor.breakUndoCoalescing()
            editor.window?.makeFirstResponder(editor)
            refreshTableSelection(in: editor)
            if let richText = updated.copy() as? NSAttributedString { onChange(richText) }
        }

        func updateTypography(_ settings: EditorTypography, in editor: NSTextView) {
            guard settings != typography else { return }
            closePasteChoice()
            // A live Korean/Japanese composition must never be reconstructed.
            if editor.hasMarkedText() {
                pendingTypography = settings
                return
            }
            guard let storage = editor.textStorage else { return }
            let prior = typography
            let selection = editor.selectedRange()
            isConverting = true
            let display = EditorTypography.normalized(storage, fromReferenceSize: prior.size, to: settings)
            storage.beginEditing()
            storage.setAttributedString(display)
            storage.endEditing()
            editor.font = settings.bodyFont
            editor.defaultParagraphStyle = settings.defaultParagraphStyle
            if storage.length == 0 { editor.typingAttributes = settings.standardTypingAttributes() }
            editor.setSelectedRange(NSRange(location: min(selection.location, storage.length),
                                           length: min(selection.length, storage.length - min(selection.location, storage.length))))
            typography = settings
            pendingTypography = nil
            isConverting = false
            // Deliberately do not call onChange or didChangeText: a preference
            // change must not create revisions or rewrite the saved HTML.
        }

        func textDidChange(_ notification: Notification) {
            guard !isConverting,
                  let editor = notification.object as? NSTextView,
                  let storage = editor.textStorage else { return }

            // Edits and Undo/Redo invalidate the offered paste range.
            if !isPasting { closePasteChoice() }
            // Never transform a paste, undo/redo, or a Korean/Japanese composition.
            let undoManager = editor.undoManager
            let isUndoRedo = undoManager?.isUndoing == true || undoManager?.isRedoing == true
            if !isPasting && !isUndoRedo && !editor.hasMarkedText(),
               editor.selectedRange().length == 0 {
                if !applyCompletedShortcut(in: editor) {
                    _ = processListReturn(in: editor)
                }
            }
            refreshTableSelection(in: editor)
            if let richText = storage.copy() as? NSAttributedString { onChange(richText) }
            if !editor.hasMarkedText(), let pending = pendingTypography {
                updateTypography(pending, in: editor)
            }
            if !editor.hasMarkedText(), editor.selectedRange().length == 0 {
                let caret = editor.selectedRange().location
                let text = storage.string as NSString
                if caret > 0 && caret <= text.length {
                    let start = text.lineRange(for: NSRange(location: caret-1, length: 0)).location
                    if text.substring(with: NSRange(location: start, length: caret-start)) == "/" {
                        DispatchQueue.main.async { self.onSlash() }
                    }
                }
            }
        }

        func apply(_ request: WorkOSFormatRequest, in editor: NSTextView?) {
            closePasteChoice()
            guard let editor, let storage = editor.textStorage else { return }
            editor.window?.makeFirstResponder(editor)
            isConverting = true
            defer { isConverting = false }
            var range = editor.selectedRange()
            if request.removeSlash && range.length == 0 && range.location > 0 {
                let preceding = (storage.string as NSString).substring(with: NSRange(location: range.location - 1, length: 1))
                if preceding == "/" {
                    let target = NSRange(location: range.location - 1, length: 1)
                    if editor.shouldChangeText(in: target, replacementString: "") {
                        storage.replaceCharacters(in: target, with: "")
                        range.location -= 1
                        editor.setSelectedRange(range)
                    }
                }
            }
            let action = request.action
            switch action {
            case .ink:
                // No rewriting all paragraphs; change the selection only or
                // the insertion-point style for subsequent typing.
                guard !editor.hasMarkedText() else { return }
                let color = request.inkHex.flatMap(EditorInk.customColor(hex:))
                    ?? request.inkPreset?.color ?? .labelColor
                if range.length > 0 {
                    guard editor.shouldChangeText(in: range, replacementString: nil) else { return }
                    editor.setTextColor(color, range: range)
                } else {
                    var attributes = editor.typingAttributes
                    attributes[.foregroundColor] = color
                    editor.typingAttributes = attributes
                    return
                }
            case .bold, .italic, .strikethrough, .code:
                var attrs = editor.typingAttributes
                let existingFont = attrs[.font] as? NSFont ?? editor.font ?? typography.bodyFont
                switch action {
                case .bold: attrs[.font] = NSFontManager.shared.convert(existingFont, toHaveTrait: .boldFontMask)
                case .italic: attrs[.font] = NSFontManager.shared.convert(existingFont, toHaveTrait: .italicFontMask)
                case .strikethrough: attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                case .code: attrs[.font] = NSFont.monospacedSystemFont(ofSize: typography.size, weight: .regular)
                default: break
                }
                if range.length > 0 { storage.addAttributes(attrs, range: range) }
                else { editor.typingAttributes = attrs }
            case .heading1, .heading2, .heading3:
                let level: Int = action == .heading1 ? 1 : (action == .heading2 ? 2 : 3)
                let attrs = paragraphAttributes(for: .heading(level))
                let paragraphRange = (storage.string as NSString).paragraphRange(for: range)
                if paragraphRange.length > 0 { storage.addAttributes(attrs, range: paragraphRange) }
                editor.typingAttributes = attrs
            case .removeSlash: break
            case .quote, .bullet, .numbered, .checklist, .divider, .link:
                let insertion: String
                switch action {
                case .quote: insertion = "❝ "
                case .bullet: insertion = "• "
                case .numbered: insertion = "1. "
                case .checklist: insertion = "☐ "
                case .divider: insertion = "────────────\n"
                case .link: insertion = "[링크 제목](https://)"
                default: insertion = ""
                }
                if editor.shouldChangeText(in: range, replacementString: insertion) {
                    storage.replaceCharacters(in: range, with: insertion)
                    editor.setSelectedRange(NSRange(location: range.location + (insertion as NSString).length, length: 0))
                    if action == .quote { editor.typingAttributes = paragraphAttributes(for: .quote) }
                    if action == .bullet { editor.typingAttributes = paragraphAttributes(for: .bullet) }
                    if action == .numbered { editor.typingAttributes = paragraphAttributes(for: .numbered) }
                    if action == .checklist { editor.typingAttributes = paragraphAttributes(for: .checklist(false)) }
                }
            }
            editor.didChangeText()
            if let rich = storage.copy() as? NSAttributedString { onChange(rich) }
        }

        private func applyCompletedShortcut(in editor: NSTextView) -> Bool {
            guard let storage = editor.textStorage else { return false }
            let caret = editor.selectedRange().location
            guard caret <= storage.length else { return false }
            if let block = LiveMarkdown.block(in: storage.string, caret: caret) {
                convertBlock(block, in: editor)
                return true
            }
            if let inline = LiveMarkdown.inline(in: storage.string, caret: caret) {
                convertInline(inline, in: editor)
                return true
            }
            return false
        }

        private func convertInline(_ match: LiveMarkdown.InlineMatch, in editor: NSTextView) {
            guard let storage = editor.textStorage else { return }
            let selected = NSMutableAttributedString(attributedString: storage.attributedSubstring(from: match.contentRange))
            guard selected.length > 0 else { return }
            let whole = NSRange(location: 0, length: selected.length)
            let original = selected.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
                ?? editor.font ?? typography.bodyFont
            switch match.kind {
            case .bold:
                selected.addAttribute(.font, value: NSFontManager.shared.convert(original, toHaveTrait: .boldFontMask), range: whole)
            case .italic:
                selected.addAttribute(.font, value: NSFontManager.shared.convert(original, toHaveTrait: .italicFontMask), range: whole)
            case .strikethrough:
                selected.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: whole)
            case .code:
                selected.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: original.pointSize, weight: .regular), range: whole)
            case .link(let address):
                guard let url = URL(string: address) else { return }
                selected.addAttribute(.link, value: url, range: whole)
                selected.addAttribute(.foregroundColor, value: NSColor.linkColor, range: whole)
                selected.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: whole)
            }
            let priorTyping = editor.typingAttributes
            isConverting = true
            defer { isConverting = false }
            guard editor.shouldChangeText(in: match.range, replacementString: selected.string) else { return }
            storage.replaceCharacters(in: match.range, with: selected)
            let insertionPoint = match.range.location + selected.length
            editor.setSelectedRange(NSRange(location: insertionPoint, length: 0))
            editor.didChangeText()
            // A closing ** or ` marker finishes this span; new text should use
            // the paragraph's former typing style, not continue the bold/code span.
            editor.typingAttributes = priorTyping
        }

        private func convertBlock(_ match: LiveMarkdown.BlockMatch, in editor: NSTextView) {
            guard let storage = editor.textStorage else { return }
            let newCaret = match.range.location + (match.replacement as NSString).length
            isConverting = true
            defer { isConverting = false }
            guard editor.shouldChangeText(in: match.range, replacementString: match.replacement) else { return }
            if match.range.length > 0 {
                storage.replaceCharacters(in: match.range, with: match.replacement)
            }
            let length = storage.length
            let rest = (storage.string as NSString).paragraphRange(
                for: NSRange(location: min(newCaret, length), length: 0))
            let style = paragraphAttributes(for: match.kind)
            if rest.length > 0 { storage.addAttributes(style, range: rest) }
            editor.setSelectedRange(NSRange(location: newCaret, length: 0))
            editor.typingAttributes = style
            editor.didChangeText()
            // NSTextView can recalculate typing attrs during didChangeText().
            editor.typingAttributes = style
        }

        private func paragraphAttributes(for kind: LiveMarkdown.BlockKind) -> [NSAttributedString.Key: Any] {
            let paragraph = typography.defaultParagraphStyle
            var font = typography.bodyFont
            var color: NSColor = .labelColor
            switch kind {
            case .heading(let level):
                switch level {
                case 1: font = .systemFont(ofSize: typography.size * 1.64, weight: .bold); paragraph.paragraphSpacing = typography.paragraphSpacing + 7
                case 2: font = .systemFont(ofSize: typography.size * 1.35, weight: .semibold); paragraph.paragraphSpacing = typography.paragraphSpacing + 4
                default: font = .systemFont(ofSize: typography.size * 1.12, weight: .semibold); paragraph.paragraphSpacing = typography.paragraphSpacing + 2
                }
            case .quote:
                paragraph.firstLineHeadIndent = 18
                paragraph.headIndent = 18
                color = .secondaryLabelColor
            case .bullet, .numbered, .checklist:
                paragraph.firstLineHeadIndent = 6
                paragraph.headIndent = 27
            }
            return [.font: font, .paragraphStyle: paragraph, .foregroundColor: color]
        }

        private func processListReturn(in editor: NSTextView) -> Bool {
            guard let storage = editor.textStorage else { return false }
            let caret = editor.selectedRange().location
            let text = storage.string as NSString
            guard caret > 0, caret <= text.length,
                  text.substring(with: NSRange(location: caret - 1, length: 1)) == "\n" else { return false }
            let precedingLine = text.lineRange(for: NSRange(location: caret - 1, length: 0))
            guard precedingLine.location <= caret - 1 else { return false }
            let oldLineLength = caret - precedingLine.location - 1
            let content = text.substring(with: NSRange(location: precedingLine.location, length: oldLineLength))
            guard let continuation = LiveMarkdown.continuation(after: content) else {
                // Heading and quote styles must not leak into the next paragraph.
                editor.typingAttributes = typography.standardTypingAttributes()
                return false
            }
            isConverting = true
            defer { isConverting = false }
            if continuation.empty {
                // Return on an empty list item exits the list.
                let remove = NSRange(location: precedingLine.location, length: (content as NSString).length)
                guard editor.shouldChangeText(in: remove, replacementString: "") else { return false }
                storage.replaceCharacters(in: remove, with: "")
                editor.setSelectedRange(NSRange(location: caret - remove.length, length: 0))
                editor.typingAttributes = typography.standardTypingAttributes()
            } else {
                guard editor.shouldChangeText(in: NSRange(location: caret, length: 0), replacementString: continuation.prefix) else { return false }
                storage.replaceCharacters(in: NSRange(location: caret, length: 0), with: continuation.prefix)
                editor.setSelectedRange(NSRange(location: caret + (continuation.prefix as NSString).length, length: 0))
            }
            editor.didChangeText()
            return true
        }
    }
}

struct ReadonlyTextView: NSViewRepresentable {
    let text: String
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 580, height: 600))
        editor.isEditable = false
        editor.isSelectable = true
        editor.isRichText = false
        editor.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        editor.textContainerInset = NSSize(width: 14, height: 14)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.string = text
        scroll.documentView = editor
        return scroll
    }
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let editor = nsView.documentView as? NSTextView, editor.string != text { editor.string = text }
    }
}
