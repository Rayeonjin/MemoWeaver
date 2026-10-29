import AppKit

@main
struct NativeTableSelectionSmoke {
    static func main() {
        let table = NSTextTable()
        table.numberOfColumns = 3
        let document = NSMutableAttributedString(string: "앞 내용😀\n")
        let start = document.length
        let rows = [["업무", "담당", "상태"], ["서버 점검", "김철수", "완료"], ["오류 분석", "이영희", "진행 중"]]
        for (row, values) in rows.enumerated() {
            for (col, value) in values.enumerated() {
                let block = NSTextTableBlock(table: table, startingRow: row,
                                              rowSpan: 1, startingColumn: col, columnSpan: 1)
                let style = NSMutableParagraphStyle()
                style.textBlocks = [block]
                document.append(NSAttributedString(string: value + "\n", attributes: [.paragraphStyle: style]))
            }
        }
        let end = document.length
        document.append(NSAttributedString(string: "뒤 내용"))
        let caret = (document.string as NSString).range(of: "김철수").location + 1
        assert(WorkOSNativeTableConversion.cursorIsInsideTable(in: document, selection: NSRange(location: caret, length: 0)))
        let offer = WorkOSNativeTableConversion.offer(in: document, selection: NSRange(location: caret, length: 0))
        assert(offer?.range == NSRange(location: start, length: end - start))
        assert(offer?.plainText == "업무\t담당\t상태\n서버 점검\t김철수\t완료\n오류 분석\t이영희\t진행 중\n")
        assert((document.string as NSString).replacingCharacters(in: offer!.range, with: offer!.plainText)
               == "앞 내용😀\n업무\t담당\t상태\n서버 점검\t김철수\t완료\n오류 분석\t이영희\t진행 중\n뒤 내용")
        assert(!WorkOSNativeTableConversion.cursorIsInsideTable(in: document, selection: NSRange(location: 0, length: 0)))
        assert(WorkOSNativeTableConversion.offer(in: document, selection: NSRange(location: 0, length: 0)) == nil)
        assert(WorkOSNativeTableConversion.offer(in: document, selection: NSRange(location: caret, length: 3)) == nil)
        assert(WorkOSNativeTableConversion.offer(in: document, selection: NSRange(location: end, length: 0)) == nil)
        // When the table is the last thing in the note, a caret at EOF is in its final cell.
        let noSuffix = document.attributedSubstring(from: NSRange(location: 0, length: end))
        assert(WorkOSNativeTableConversion.offer(in: noSuffix, selection: NSRange(location: end, length: 0)) != nil)

        // Adjacent tables must not be swallowed as a single conversion range.
        let anotherTable = NSTextTable()
        anotherTable.numberOfColumns = 1
        let anotherBlock = NSTextTableBlock(table: anotherTable, startingRow: 0,
                                              rowSpan: 1, startingColumn: 0, columnSpan: 1)
        let anotherStyle = NSMutableParagraphStyle()
        anotherStyle.textBlocks = [anotherBlock]
        let adjacent = NSMutableAttributedString(attributedString: noSuffix)
        adjacent.append(NSAttributedString(string: "별도 표\n", attributes: [.paragraphStyle: anotherStyle]))
        let first = WorkOSNativeTableConversion.offer(in: adjacent,
                    selection: NSRange(location: caret, length: 0))
        assert(first?.range.length == end - start)
        let last = WorkOSNativeTableConversion.offer(in: adjacent,
                    selection: NSRange(location: adjacent.length, length: 0))
        assert(last?.plainText == "별도 표\n")
        print("PASS: native NSTextTable selection, precise UTF-16 replacement, multiple tables, EOF and adjacent text")
    }
}
