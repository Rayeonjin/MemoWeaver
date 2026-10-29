import Foundation

// This narrow Foundation-only test supplies the same HTML escaping contract as
// Storage.swift without opening SQLite or the real WorkOS database.
func escapeHTML(_ text: String) -> String {
    text.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}

@main
struct NoteSidePreviewSmoke {
    static func main() {
        // Plain notes must stay single-pane until the user opens the preview.
        assert(!NotePreviewRules.autoOpen(bodyHTML: "<p>한글 일반 메모</p>", blocks: []))
        assert(!NotePreviewRules.autoOpen(bodyHTML: "", blocks: []))
        assert(NotePreviewRules.autoOpen(bodyHTML: "<h2>문서 제목</h2>", blocks: []))
        assert(NotePreviewRules.autoOpen(bodyHTML: "<TABLE><tr></tr></TABLE>", blocks: []))
        assert(NotePreviewRules.autoOpen(bodyHTML: "<blockquote>인용</blockquote>", blocks: []))
        let table = WorkBlock(id: "tb", kind: .table,
                              source: "| 항목 | 내용 |\n| --- | --- |\n| 상태 | 정상 |")
        let math = WorkBlock(id: "eq", kind: .equation, source: #"x^2 + y^2"#)
        let diagram = WorkBlock(id: "mg", kind: .mermaid,
                                source: "flowchart TD\n  A[시작] --> B[종료]")
        let blocks = [table, math, diagram]
        assert(NotePreviewRules.autoOpen(bodyHTML: "<p>일반 본문</p>", blocks: blocks))
        // One panel: formatted notes auto-open only on the preview tab.
        assert(NoteSidePaneRules.isVisible(override: nil, tab: .preview,
                    bodyHTML: "<h2>제목</h2>", blocks: []))
        assert(!NoteSidePaneRules.isVisible(override: nil, tab: .reference,
                    bodyHTML: "<h2>제목</h2>", blocks: []))
        assert(!NoteSidePaneRules.isVisible(override: nil, tab: .memory,
                    bodyHTML: "<h2>제목</h2>", blocks: []))
        assert(!NoteSidePaneRules.isVisible(override: nil, tab: .preview,
                    bodyHTML: "<p>일반 메모</p>", blocks: []))
        // One toolbar toggle controls visibility regardless of the selected tab.
        assert(NoteSidePaneRules.isVisible(override: true, tab: .preview,
                    bodyHTML: "", blocks: []))
        assert(NoteSidePaneRules.isVisible(override: true, tab: .reference,
                    bodyHTML: "", blocks: []))
        assert(NoteSidePaneRules.isVisible(override: true, tab: .memory,
                    bodyHTML: "", blocks: []))
        assert(!NoteSidePaneRules.isVisible(override: false, tab: .preview,
                    bodyHTML: "<h2>제목</h2>", blocks: blocks))
        assert(!NoteSidePaneRules.isVisible(override: false, tab: .reference,
                    bodyHTML: "<h2>제목</h2>", blocks: blocks))
        // Closing the panel is a durable user choice across every tab/note.
        assert(NoteSidePaneRules.overrideAfterNoteChange(current: true, tab: .reference) == true)
        assert(NoteSidePaneRules.overrideAfterNoteChange(current: true, tab: .memory) == true)
        assert(NoteSidePaneRules.overrideAfterNoteChange(current: true, tab: .preview) == true)
        assert(NoteSidePaneRules.overrideAfterNoteChange(current: false, tab: .reference) == false)
        assert(NoteSidePaneRules.overrideAfterNoteChange(current: false, tab: .preview) == false)
        assert(NoteSidePaneRules.overrideAfterNoteChange(current: false, tab: .memory) == false)
        assert(NoteSidePaneRules.overrideAfterNoteChange(current: nil, tab: .preview) == nil)
        assert(NoteSidePaneRules.visibilityOverride(preference: "automatic") == nil)
        assert(NoteSidePaneRules.visibilityOverride(preference: "closed") == false)
        assert(NoteSidePaneRules.visibilityOverride(preference: "open") == true)
        assert(NoteSidePaneRules.visibilityOverride(preference: "unexpected") == nil)
        for width: CGFloat in [400, 500, 700, 1000, 1380, 2200] {
            let sizes = NoteWorkspaceLayout.widths(
                availableWidth: width, listVisible: false, rightPanelVisible: true)
            assert(abs(sizes.total - width) <= 0.01)
            assert(sizes.editor > 0 && sizes.right > 0)
            assert(sizes.editor >= sizes.right || width > 1300)
            assert(sizes.right <= NoteWorkspaceLayout.maximumRightWidth)
        }
        let stored = WorkNote.from([
            "id": "side-preview-test", "title": "검토 보고서", "body": "<h2>현황</h2><p>기존 데이터 유지</p>",
            "noteDate": "2026-10-21", "status": "진행 중",
            "workosBlocks": WorkBlock.encode(blocks), "mysteryLegacyField": "keep-me"
        ])
        let before = stored.rawJSON
        let original = NoteDocuments.html(note: stored)
        let equalLive = NoteDocuments.livePreviewHTML(
            title: stored.visibleTitle, noteDate: stored.noteDate, status: stored.status,
            bodyHTML: stored.bodyHTML, blocks: stored.workosBlocks)
        assert(original == equalLive, "Export and side preview must share one rendering path")
        assert(original.contains("<table class='workos-table'>"))
        assert(original.contains("class='formula'"))
        assert(original.contains("x^2 + y^2"))
        assert(original.contains("<svg"), "Supported Mermaid flowcharts render offline")
        assert(original.contains("기존 데이터 유지"))
        assert(stored.rawJSON == before, "Preview must not change stored note JSON")

        // Live preview must include uncommitted source without saving it.
        let updated = NoteDocuments.livePreviewHTML(
            title: "수정 중 & 검토", noteDate: "2026-10-22", status: "대기",
            bodyHTML: "<p>저장 전 텍스트</p><script>alert('network')</script>", blocks: [math])
        assert(updated.contains("수정 중 &amp; 검토"))
        assert(updated.contains("저장 전 텍스트"))
        assert(!updated.contains("alert('network')"), "Script from note must not enter HTML preview")
        assert(updated.contains("class='formula'"))
        assert(!updated.contains("<table class='workos-table'>"))
        assert(stored.rawJSON == before && stored.title == "검토 보고서")
        print("PASS persistent side-pane close/open across notes, responsive split widths, live preview, offline Mermaid/math, JSON preservation")
    }
}
