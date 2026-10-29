import AppKit

// Detect tables already present in the rich-text document, including tables
// restored from HTML. Unlike the paste-only choice, this does not depend on
// the clipboard, a remembered paste position, or a new database field.
enum WorkOSNativeTableConversion {
    struct Offer {
        let range: NSRange  // Entire existing table, in NSTextStorage UTF-16 offsets.
        let plainText: String
    }

    // Called on every caret move; do not scan/allocate the entire table here.
    static func cursorIsInsideTable(in content: NSAttributedString, selection: NSRange) -> Bool {
        guard selection.length == 0, selection.location != NSNotFound,
              selection.location >= 0, selection.location <= content.length,
              content.length > 0 else { return false }
        let probe = selection.location == content.length ? content.length - 1 : selection.location
        return tableBlock(in: content, at: probe) != nil
    }

    static func offer(in content: NSAttributedString, selection: NSRange) -> Offer? {
        guard selection.length == 0, selection.location != NSNotFound,
              selection.location >= 0, selection.location <= content.length,
              content.length > 0 else { return nil }
        let source = content.string as NSString
        // The insertion point at end-of-document belongs to the last cell.
        // Everywhere else, inspect the character *at* the insertion point:
        // looking back would mistakenly offer to convert an adjacent table.
        let probe = selection.location == content.length ? content.length - 1 : selection.location
        guard let selectedBlock = tableBlock(in: content, at: probe) else { return nil }
        let table = selectedBlock.table
        let center = source.paragraphRange(for: NSRange(location: probe, length: 0))

        var start = center.location
        while start > 0 {
            let previous = source.paragraphRange(for: NSRange(location: start - 1, length: 0))
            guard let block = tableBlock(in: content, at: previous.location),
                  block.table === table else { break }
            start = previous.location
        }

        var end = NSMaxRange(center)
        while end < content.length {
            let next = source.paragraphRange(for: NSRange(location: end, length: 0))
            guard let block = tableBlock(in: content, at: next.location),
                  block.table === table else { break }
            end = NSMaxRange(next)
        }
        guard end > start else { return nil }

        var cells: [WorkOSPlainTableCell] = []
        var cellPositions: [String: Int] = [:]
        var cursor = start
        while cursor < end {
            let paragraph = source.paragraphRange(for: NSRange(location: cursor, length: 0))
            guard let block = tableBlock(in: content, at: cursor), block.table === table,
                  block.startingRow >= 0, block.startingColumn >= 0,
                  block.rowSpan > 0, block.columnSpan > 0 else { return nil }
            let raw = source.substring(with: paragraph)
            // Images and embedded attachments cannot be represented losslessly
            // as TSV; keep the original table rather than silently dropping them.
            guard !raw.contains("\u{FFFC}") else { return nil }
            var cellText = raw
            while let last = cellText.last, last.isNewline { cellText.removeLast() }
            let key = "\(block.startingRow):\(block.startingColumn)"
            if let index = cellPositions[key] {
                let previous = cells[index]
                guard previous.rowSpan == block.rowSpan,
                      previous.columnSpan == block.columnSpan else { return nil }
                cells[index].text += "\n" + cellText
            } else {
                cellPositions[key] = cells.count
                cells.append(WorkOSPlainTableCell(row: block.startingRow,
                                                  column: block.startingColumn,
                                                  rowSpan: block.rowSpan,
                                                  columnSpan: block.columnSpan,
                                                  text: cellText))
            }
            cursor = NSMaxRange(paragraph)
        }
        guard let tsv = WorkOSPasteTable.tableText(cells: cells, columnCount: table.numberOfColumns) else { return nil }
        // Keep the separating newline so that a following normal paragraph is
        // not merged into the last table row during replacement.
        let original = source.substring(with: NSRange(location: start, length: end - start))
        let hasEndingBreak = original.hasSuffix("\n") || original.hasSuffix("\r") || original.hasSuffix("\u{2029}")
        return Offer(range: NSRange(location: start, length: end - start),
                     plainText: tsv + (hasEndingBreak ? "\n" : ""))
    }

    private static func tableBlock(in content: NSAttributedString, at location: Int) -> NSTextTableBlock? {
        guard location >= 0, location < content.length,
              let style = content.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle else { return nil }
        // For nested tables, the last text block is the cell directly under
        // the cursor (outer blocks come first).
        return style.textBlocks.compactMap { $0 as? NSTextTableBlock }.last
    }
}
