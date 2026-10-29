import Foundation

func check(_ statement: @autoclosure () -> Bool, _ detail: String) {
    if !statement() { fputs("FAIL: \(detail)\n", stderr); exit(1) }
}

@main
struct EditorLineNumberSmoke {
static func main() {
let empty = EditorLineNumberRules.lineStarts(in: "")
check(empty == [0], "empty note has a visible line 1")
check(EditorLineNumberRules.lineStarts(in: "first\nsecond\n") == [0, 6, 13], "trailing newline has final line")
check(EditorLineNumberRules.lineStarts(in: "a\r\nb\rc\nd") == [0, 3, 5, 7], "CRLF, CR and LF are supported")
check(EditorLineNumberRules.lineStarts(in: "a\u{2028}b\u{2029}c") == [0, 2, 4], "Unicode separators count as hard breaks")
let hangulEmoji = "한글😀\nSecond line"
let starts = EditorLineNumberRules.lineStarts(in: hangulEmoji)
check(starts == [0, 5], "NSString-style UTF-16 offsets with emoji")
check(EditorLineNumberRules.lineIndex(forUTF16Offset: 4, starts: starts) == 0, "newline belongs to first line")
check(EditorLineNumberRules.lineIndex(forUTF16Offset: 5, starts: starts) == 1, "caret starts second line")
check(EditorLineNumberRules.isFirstVisualRow(atUTF16Offset: 0, starts: starts), "first visual row has number")
check(!EditorLineNumberRules.isFirstVisualRow(atUTF16Offset: 2, starts: starts), "soft wrap does not repeat number")
check(EditorLineNumberRules.isFirstVisualRow(atUTF16Offset: 5, starts: starts), "second logical line has number")
let large = (1...11_005).map { "줄 \($0)" }.joined(separator: "\n")
let many = EditorLineNumberRules.lineStarts(in: large)
check(many.count == 11_005, "large imported scratchpad line count")
check(EditorLineNumberRules.lineIndex(forUTF16Offset: large.utf16.count, starts: many) == 11_004,
      "end of large document retains correct number")
print("PASS UTF-16 logical line numbers, wrap, newlines, emoji, 11,005-line document")

}
}
