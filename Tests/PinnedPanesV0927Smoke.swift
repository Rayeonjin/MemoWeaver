import Foundation

@main struct PinnedPanesV0927Smoke {
    static func check(_ yes: @autoclosure () -> Bool, _ message: String) {
        if !yes() { fputs("FAIL: \(message)\n", stderr); exit(1) }
    }
    static func main() {
        typealias P = MemoWeaverPinnedPaneLayout
        // A 52pt rail and ~2pt native dividers fit inside typical app widths.
        for windowWidth in stride(from: 970, through: 1600, by: 5) {
            let detail = CGFloat(windowWidth - 53)
            let both = P.resolved(totalWidth: detail, dividerThickness: 1,
                listVisible: true, rightVisible: true,
                savedListWidth: 265, savedRightWidth: 365)
            check(abs(both.list - 265) < 0.01, "list must not resize with window")
            check(abs(both.right - 365) < 0.01, "right must not resize with window")
            check(abs(both.total - detail) < 0.01, "only editor absorbs window delta")
            check(both.editor >= 240, "editor minimum at normal window sizes")
            let closed = P.resolved(totalWidth: detail, dividerThickness: 1,
                listVisible: true, rightVisible: false,
                savedListWidth: 265, savedRightWidth: 365)
            check(abs(closed.list - both.list) < 0.01, "closing right leaves list untouched")
            check(abs(closed.editor - both.editor - both.right - 1) < 0.01,
                  "closing right adds its space only to editor")
            let reopened = P.resolved(totalWidth: detail, dividerThickness: 1,
                listVisible: true, rightVisible: true,
                savedListWidth: 265, savedRightWidth: 365)
            check(abs(reopened.right - 365) < 0.01, "reopened right restores saved width")
        }
        let defaultWidth = P.resolved(totalWidth: 1100, dividerThickness: 1,
            listVisible: true, rightVisible: true,
            savedListWidth: 0, savedRightWidth: 0)
        check(defaultWidth.list == 245 && defaultWidth.right == 340, "fixed initial widths")
        let focus = P.resolved(totalWidth: 930, dividerThickness: 1,
            listVisible: false, rightVisible: false,
            savedListWidth: 300, savedRightWidth: 520)
        check(focus.editor == 930 && focus.list == 0 && focus.right == 0, "focus uses full width")
        let rightOnly = P.resolved(totalWidth: 930, dividerThickness: 1,
            listVisible: false, rightVisible: true,
            savedListWidth: 300, savedRightWidth: 520)
        check(rightOnly.right == 520, "list closed has no side effects on right")
        let constrained = P.resolved(totalWidth: 740, dividerThickness: 1,
            listVisible: true, rightVisible: true,
            savedListWidth: 300, savedRightWidth: 450)
        check(constrained.list == 300, "preserve list first if the window is too narrow")
        check(constrained.editor >= 240 && constrained.right >= 190,
              "squeeze right first when impossible to preserve both")
        let returnWide = P.resolved(totalWidth: 1500, dividerThickness: 1,
            listVisible: true, rightVisible: true,
            savedListWidth: 300, savedRightWidth: 450)
        check(returnWide.list == 300 && returnWide.right == 450,
              "temporary compression never overwrites stored widths")
        let extreme = P.resolved(totalWidth: 300, dividerThickness: 1,
            listVisible: true, rightVisible: true, savedListWidth: 300, savedRightWidth: 450)
        check(extreme.total == 300 && extreme.editor >= 0, "no negative frames")
        print("PASS v0.9.27: pinned widths, window resizing, panel toggling, focus, last right width, minimum constraints")
    }
}
