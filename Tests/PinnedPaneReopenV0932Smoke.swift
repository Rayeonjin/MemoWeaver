import Foundation

@main struct PinnedPaneReopenV0932Smoke {
    static func verify(_ test: @autoclosure () -> Bool, _ label: String) {
        guard test() else { fputs("FAIL v0.9.32 pinned-pane: \(label)\n", stderr); exit(1) }
    }
    static func main() {
        typealias P = MemoWeaverPinnedPaneLayout
        for width in stride(from: 1000, through: 2000, by: 13) {
            for listTarget: CGFloat in [190, 245, 310, 375, 420] {
                for rightTarget: CGFloat in [190, 290, 390, 520] {
                    // 1. Right closed, resize only list, and reopen right.
                    let before = P.resolved(totalWidth: CGFloat(width), dividerThickness: 1,
                        listVisible: true, rightVisible: false,
                        savedListWidth: 245, savedRightWidth: rightTarget)
                    verify(abs(before.list - 245) < 0.001, "unexpected initial list width")
                    let newList = P.userWidthBeforeVisibilityChange(pane: .list,
                        observed: listTarget, totalWidth: CGFloat(width), dividerThickness: 1,
                        listVisible: true, rightVisible: false,
                        savedListWidth: 245, savedRightWidth: rightTarget)
                    let captured = listTarget == 245 ? CGFloat(245) : newList
                    verify(captured != nil, "failed to capture list resized while right closed")
                    let reopened = P.resolved(totalWidth: CGFloat(width), dividerThickness: 1,
                        listVisible: true, rightVisible: true,
                        savedListWidth: captured!, savedRightWidth: rightTarget)
                    // When editor has enough space, the side widths must be exact.
                    if CGFloat(width) >= listTarget + rightTarget + P.editorMinimum + 2 {
                        verify(abs(reopened.list - listTarget) < 0.001,
                               "reopening right changed list preference")
                        verify(abs(reopened.right - rightTarget) < 0.001,
                               "right width lost across reopen")
                    }
                    // 2. Closing and reopening without a new drag must not
                    // rewrite either preference, regardless of pane state.
                    let closed = P.resolved(totalWidth: CGFloat(width), dividerThickness: 1,
                        listVisible: true, rightVisible: false,
                        savedListWidth: captured!, savedRightWidth: rightTarget)
                    verify(abs(closed.list - captured!) < 0.001, "close modified selected list width")
                }
            }
        }
        // Narrow-window compression must never overwrite a stored preference.
        let narrow = P.resolved(totalWidth: 610, dividerThickness: 1,
            listVisible: true, rightVisible: true,
            savedListWidth: 390, savedRightWidth: 420)
        let wronglySaved = P.userWidthBeforeVisibilityChange(pane: .list,
            observed: narrow.list, totalWidth: 610, dividerThickness: 1,
            listVisible: true, rightVisible: true,
            savedListWidth: 390, savedRightWidth: 420)
        verify(wronglySaved == nil, "persisted temporary list compression")
        let restored = P.resolved(totalWidth: 1440, dividerThickness: 1,
            listVisible: true, rightVisible: true,
            savedListWidth: 390, savedRightWidth: 420)
        verify(abs(restored.list - 390) < 0.001 && abs(restored.right - 420) < 0.001,
               "wide window failed to restore both preferences")
        print("PASS v0.9.32 reopen-right-after-list-resize, preference preservation, narrow-window guard")
    }
}
