import Foundation

@main struct PinnedPanesV0928Smoke {
    static func check(_ ok: @autoclosure () -> Bool, _ message: String) {
        if !ok() { fputs("FAIL: \(message)\n", stderr); exit(1) }
    }

    static func main() {
        typealias P = MemoWeaverPinnedPaneLayout
        let divider: CGFloat = 1
        for listPreference: CGFloat in [175, 245, 285, 365, 420] {
            for rightPreference: CGFloat in [190, 340, 410, 610] {
                // The geometry, not the user's saved preference, may temporarily
                // compress a pane. At normal widths, both widths must be exact.
                let minimumWidth = listPreference + rightPreference + P.editorMinimum + 2 * divider
                for width in stride(from: Int(minimumWidth), through: 1880, by: 13) {
                    let w = CGFloat(width)
                    let open = P.resolved(totalWidth: w, dividerThickness: divider,
                        listVisible: true, rightVisible: true,
                        savedListWidth: listPreference, savedRightWidth: rightPreference)
                    let closed = P.resolved(totalWidth: w, dividerThickness: divider,
                        listVisible: true, rightVisible: false,
                        savedListWidth: listPreference, savedRightWidth: rightPreference)
                    let restored = P.resolved(totalWidth: w, dividerThickness: divider,
                        listVisible: true, rightVisible: true,
                        savedListWidth: listPreference, savedRightWidth: rightPreference)
                    check(abs(open.list - listPreference) < 0.01, "right opening changed list width")
                    check(abs(closed.list - listPreference) < 0.01, "right closing changed list width")
                    check(abs(open.right - rightPreference) < 0.01, "right opening ignored last width")
                    check(abs(restored.right - rightPreference) < 0.01, "reopen did not restore width")
                    check(abs(open.editor - (w - listPreference - rightPreference - 2 * divider)) < 0.01,
                          "central editor did not absorb window width")
                    check(abs(closed.editor - open.editor - rightPreference - divider) < 0.01,
                          "closing right did not give full width to editor")
                    check(abs(open.total - w) < 0.01 && abs(closed.total - w) < 0.01,
                          "divider/frame arithmetic mismatch")
                }
            }
        }
        for width in [CGFloat(0), 110, 200, 420, 740, 970] {
            let narrow = P.resolved(totalWidth: width, dividerThickness: divider,
                listVisible: true, rightVisible: true,
                savedListWidth: 375, savedRightWidth: 590)
            check(narrow.list >= 0 && narrow.right >= 0 && narrow.editor >= 0,
                  "negative frame width when very narrow")
            check(abs(narrow.total - width) < 0.01, "narrow frame overlap")
        }
        print("PASS v0.9.28 pane sizing: 1000+ resize/open/close/restore combinations, constrained layouts")
    }
}
