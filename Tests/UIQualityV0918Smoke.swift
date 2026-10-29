import Foundation

@main
struct UIQualityV0918Smoke {
    static func main() {
        for width: CGFloat in [970, 1024, 1200, 1240, 1241, 1320, 1440] {
            let detail = width - 156
            let sizes = NoteWorkspaceLayout.widths(
                availableWidth: detail, listVisible: true, rightPanelVisible: true)
            print("WIDTH \(Int(width)) list=\(Int(sizes.list)) editor=\(Int(sizes.editor)) " +
                  "right=\(Int(sizes.right))")
            assert(sizes.list >= NoteWorkspaceLayout.minimumListWidth)
            assert(sizes.editor >= NoteWorkspaceLayout.minimumEditorWidth)
            assert(sizes.right >= NoteWorkspaceLayout.minimumRightWidth)
            assert(abs(sizes.total - detail) < 0.01)
        }
        let a = NoteWorkspaceLayout.widths(availableWidth: 1240 - 156,
                    listVisible: true, rightPanelVisible: true)
        let b = NoteWorkspaceLayout.widths(availableWidth: 1241 - 156,
                    listVisible: true, rightPanelVisible: true)
        assert(abs(b.editor - a.editor) <= 1.01)
        let listHidden = NoteWorkspaceLayout.widths(availableWidth: 814,
                    listVisible: false, rightPanelVisible: true)
        assert(listHidden.list == 0)
        assert(MemoWeaverStorageStatus.title(for: "저장됨 · 2026-10-26") == "이 Mac에 저장")
        assert(MemoWeaverStorageStatus.title(for: "로컬 저장소 준비 중") == "저장 중")
        assert(MemoWeaverStorageStatus.title(for: "저장 실패") == "저장 확인 필요")
        assert(MemoWeaverStorageStatus.needsAttention("SQLite 저장 가능 · 자동 백업 점검 필요"))
        assert(MemoWeaverStorageStatus.symbol(for: "저장소 오류") == "exclamationmark.triangle.fill")
        assert(!MemoWeaverStorageStatus.needsAttention("저장됨"))
        print("PASS content UI regression + v0.9.19 continuous list policy and storage status semantics")
    }
}

// WorkBlocks has HTML rendering helpers; this test never renders HTML.
// Production gets escapeHTML from Storage.swift, which deliberately stays
// outside this pure Foundation/layout test (no user DB is opened).
func escapeHTML(_ text: String) -> String { text }
