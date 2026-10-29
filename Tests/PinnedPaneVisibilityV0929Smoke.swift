import Foundation

@main struct PinnedPaneVisibilityV0929Smoke {
    static func require(_ works: @autoclosure () -> Bool, _ reason: String) {
        if !works() { fputs("FAIL v0.9.29: \(reason)\n", stderr); exit(1) }
    }
    static func main() {
        typealias P = MemoWeaverPinnedPaneLayout
        // A closed panel must cease being an NSSplitView arranged subview.
        let states: [(Bool, Bool, [P.Pane])] = [
            (true, true, [.list, .editor, .right]),
            (true, false, [.list, .editor]),
            (false, true, [.editor, .right]),
            (false, false, [.editor])
        ]
        for (listShown, rightShown, order) in states {
            let actual = P.visiblePaneOrder(listVisible: listShown, rightVisible: rightShown)
            require(actual == order, "visible arrangement mismatch")
            require(actual.count-1 == (listShown ? 1 : 0) + (rightShown ? 1 : 0),
                    "ghost divider count")
        }
        // Both close/reopen paths must preserve exactly the original pane
        // order. No trace of a removed panel survives in the arrangement.
        var order = P.visiblePaneOrder(listVisible: true, rightVisible: true)
        for _ in 0..<120 {
            order = P.visiblePaneOrder(listVisible: true, rightVisible: false)
            require(order == [.list, .editor], "right divider survived close")
            order = P.visiblePaneOrder(listVisible: true, rightVisible: true)
            require(order == [.list, .editor, .right], "right pane missing on reopen")
            order = P.visiblePaneOrder(listVisible: false, rightVisible: true)
            require(order == [.editor, .right], "list divider survived close")
            order = P.visiblePaneOrder(listVisible: true, rightVisible: true)
            require(order == [.list, .editor, .right], "list pane missing on reopen")
        }
        for width in stride(from: 660, through: 1900, by: 11) {
            for listPref: CGFloat in [175, 245, 330, 420] {
                for rightPref: CGFloat in [190, 340, 510] {
                    let initial = P.resolved(totalWidth: CGFloat(width), dividerThickness: 1,
                        listVisible: true, rightVisible: true,
                        savedListWidth: listPref, savedRightWidth: rightPref)
                    let rightClosed = P.resolved(totalWidth: CGFloat(width), dividerThickness: 1,
                        listVisible: true, rightVisible: false,
                        savedListWidth: listPref, savedRightWidth: rightPref)
                    let listClosed = P.resolved(totalWidth: CGFloat(width), dividerThickness: 1,
                        listVisible: false, rightVisible: true,
                        savedListWidth: listPref, savedRightWidth: rightPref)
                    let restored = P.resolved(totalWidth: CGFloat(width), dividerThickness: 1,
                        listVisible: true, rightVisible: true,
                        savedListWidth: listPref, savedRightWidth: rightPref)
                    require(abs(initial.total - CGFloat(width)) < 0.01, "initial total mismatch")
                    require(abs(rightClosed.total - CGFloat(width)) < 0.01, "right closed total mismatch")
                    require(abs(listClosed.total - CGFloat(width)) < 0.01, "list closed total mismatch")
                    require(abs(restored.list - initial.list) < 0.01, "list saved width changed")
                    require(abs(restored.right - initial.right) < 0.01, "right saved width changed")
                    if initial.list >= listPref - 0.01 {
                        require(abs(rightClosed.list - initial.list) < 0.01,
                                "closing right modified a pinned list width")
                    }
                    // When the window was too narrow, the list may temporarily
                    // compress, but closing the right pane restores its chosen width.
                    if CGFloat(width) >= listPref + P.editorMinimum + 1 {
                        require(abs(rightClosed.list - listPref) < 0.01,
                                "closing right did not restore chosen list width")
                    }
                }
            }
        }
        print("PASS v0.9.29 visible-pane order, no stale dividers, repeated toggles, width restoration")
    }
}
