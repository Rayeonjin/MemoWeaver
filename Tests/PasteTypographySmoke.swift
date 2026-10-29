import AppKit

@main
struct PasteTypographySmoke {
    static func main() {
        let prefix = NSAttributedString(string: "기존 본문😀\n",
                                        attributes: [.font: NSFont.systemFont(ofSize: 17)])
        let pasted = NSMutableAttributedString(string: "We offer campaigns 🏆\n한글 Korean 日本語\n")
        let serif = NSFont(name: "Times New Roman", size: 10) ?? .systemFont(ofSize: 10)
        pasted.addAttributes([.font: serif, .foregroundColor: NSColor.systemBlue],
                             range: NSRange(location: 0, length: pasted.length))
        let suffix = NSAttributedString(string: "\n기존 마지막 문장",
                                        attributes: [.font: NSFont.systemFont(ofSize: 14)])
        let note = NSMutableAttributedString(attributedString: prefix)
        let pastedRange = NSRange(location: note.length, length: pasted.length)
        note.append(pasted)
        note.append(suffix)
        let before = note.string
        assert(WorkOSPastedTypography.normalize(in: note, range: pastedRange, typography: EditorTypography()))
        let font = note.attribute(.font, at: pastedRange.location, effectiveRange: nil) as? NSFont
        assert(font != nil && font!.pointSize >= 16.5)
        assert(!(font!.familyName ?? "").contains("Times"))
        assert(note.string == before)
        assert(note.attribute(.foregroundColor, at: pastedRange.location, effectiveRange: nil) as? NSColor == .systemBlue)
        let prefixFont = note.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        assert(prefixFont?.pointSize == 17)
        let suffixFont = note.attribute(.font, at: note.length - 1, effectiveRange: nil) as? NSFont
        assert(suffixFont?.pointSize == 14)

        let table = NSTextTable()
        table.numberOfColumns = 1
        let block = NSTextTableBlock(table: table, startingRow: 0,
                                     rowSpan: 1, startingColumn: 0, columnSpan: 1)
        let tableStyle = NSMutableParagraphStyle()
        tableStyle.textBlocks = [block]
        let cell = NSMutableAttributedString(string: "셀 내용\n",
              attributes: [.font: serif, .paragraphStyle: tableStyle])
        assert(WorkOSPastedTypography.normalize(in: cell,
                range: NSRange(location: 0, length: cell.length), typography: EditorTypography()))
        let resulting = cell.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        assert((resulting?.textBlocks.first as? NSTextTableBlock)?.table === table)
        assert(!WorkOSPastedTypography.normalize(in: note,
               range: NSRange(location: NSNotFound, length: 0), typography: EditorTypography()))
        print("PASS: imported serif/10pt fonts normalized to readable system sans; note neighbors, table blocks, Unicode & ink intact")
    }
}
