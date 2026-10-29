import Foundation

@main struct MemoWeaverUIV0916Smoke {
    static func main() {
        let original = "# 거래량 변화 검토\n\n- 한국어 업무 메모\n- 다음 단계"
        precondition(MemoWeaverUIRules.titleSuggestion(original) == "거래량 변화 검토")
        precondition(MemoWeaverUIRules.titleSuggestion("\n \n") == "새 메모")
        precondition(MemoWeaverUIRules.titleSuggestion("제목이 따로 없음") == "제목이 따로 없음")
        precondition(MemoWeaverUIRules.totalLines(in: "첫 줄\n둘째 줄\n") == 3)
        precondition(MemoWeaverUIRules.totalLines(in: "") == 1)
        let hangul = "가나다\n🙂문장"
        let starts = EditorLineNumberRules.lineStarts(in: hangul)
        precondition(starts.count == 2)
        precondition(MemoWeaverUIRules.column(in: hangul, utf16Offset: starts[1], lineStart: starts[1]) == 1)
        precondition(MemoWeaverUIRules.column(in: hangul, utf16Offset: starts[1] + 2, lineStart: starts[1]) == 2)
        precondition(MemoWeaverUIRules.matchesNote(title: "거래량 변화", excerpt: "시장 기록", term: "거래량"))
        precondition(MemoWeaverUIRules.matchesNote(title: "업무 기록", excerpt: "기관 매수세", term: "매수세"))
        precondition(!MemoWeaverUIRules.matchesNote(title: "업무 기록", excerpt: "기관 매수세", term: "실적"))
        let page = "<html><head><title>Note</title></head><body><article>가나다</article></body></html>"
        let night = MemoWeaverPreviewAppearance.apply(page, dark: true)
        precondition(night.contains("memoweaver-preview-dark"))
        precondition(night.contains(".diagram-markmap"))
        precondition(night.contains("<article>가나다</article>"))
        precondition(MemoWeaverPreviewAppearance.apply(page, dark: false) == page)
        print("PASS v0.9.16 status column/lines, local search, long-note title, offline preview theme")
    }
}
