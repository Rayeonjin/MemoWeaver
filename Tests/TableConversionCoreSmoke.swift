import Foundation

@main
struct TableConversionCoreSmoke {
    static func main() {
        func cell(_ r: Int, _ c: Int, _ text: String, _ rs: Int = 1, _ cs: Int = 1) -> WorkOSPlainTableCell {
            WorkOSPlainTableCell(row: r, column: c, rowSpan: rs, columnSpan: cs, text: text)
        }
        let korean = [cell(0,0,"업무"), cell(0,1,"담당"), cell(0,2,"상태"),
                      cell(1,0,"서버 점검"), cell(1,1,"김철수"), cell(1,2,"완료"),
                      cell(2,0,"오류 분석"), cell(2,1,"이영희"), cell(2,2,"진행 중")]
        assert(WorkOSPasteTable.tableText(cells: korean, columnCount: 3)
               == "업무\t담당\t상태\n서버 점검\t김철수\t완료\n오류 분석\t이영희\t진행 중")
        assert(WorkOSPasteTable.tableText(cells: [cell(0,0,"A"), cell(0,2,"C"), cell(1,1,"B")], columnCount: 3)
               == "A\t\tC\n\tB\t")
        assert(WorkOSPasteTable.tableText(cells: [cell(0,0,"팀",2,1), cell(0,1,"A&B",1,2),
                                                       cell(1,1,"진행"), cell(1,2,"상태")], columnCount: 3)
               == "팀\tA&B\t\n\t진행\t상태")
        assert(WorkOSPasteTable.tableText(cells: [cell(0,0,"여러\n줄"), cell(0,1,"\"확인\"")], columnCount: 2)
               == "\"여러\n줄\"\t\"\"\"확인\"\"\"")
        assert(WorkOSPasteTable.tableText(cells: [cell(0,0,"한 열")], columnCount: 1) == "한 열")
        assert(WorkOSPasteTable.tableText(cells: [cell(0,0,"한 열")], columnCount: 0) == "한 열")
        // Refuse inconsistent grids instead of deleting/corrupting content.
        assert(WorkOSPasteTable.tableText(cells: [], columnCount: 1) == nil)
        assert(WorkOSPasteTable.tableText(cells: [cell(-1,0,"invalid")], columnCount: 1) == nil)
        assert(WorkOSPasteTable.tableText(cells: [cell(0,0,"A",1,2), cell(0,1,"overlap")], columnCount: 2) == nil)
        assert(WorkOSPasteTable.tableText(cells: [cell(0,0,"too wide")], columnCount: 257) == nil)
        assert(WorkOSPasteTable.tableText(cells: [cell(10_000,0,"too tall")], columnCount: 1) == nil)
        print("PASS: arbitrary-time table conversion TSV (Korean, empty/merged/multiline cells, invalid-grid refusal)")
    }
}
