import Foundation

@main struct ToolbarMinimumV0949Smoke {
    static func main() {
        func near(_ a: CGFloat, _ b: CGFloat, file: StaticString = #file, line: UInt = #line) {
            precondition(abs(a-b) < 0.001, "\(a) != \(b)", file: file, line: line)
        }
        // The INK for a borderless NSTextField used to be 5-6pt above the
        // image center. Center 19pt text and 28pt icon in the same 34pt bar.
        near(MemoWeaverToolbarGeometry.titleTextOrigin, 7.5)
        near(MemoWeaverToolbarGeometry.verticalOrigin, 3)
        near(MemoWeaverToolbarGeometry.titleTextOrigin + MemoWeaverToolbarGeometry.titleTextHeight / 2, 17)
        near(MemoWeaverToolbarGeometry.verticalOrigin + MemoWeaverToolbarGeometry.controlHeight / 2, 17)
        func minWidth(_ list: Bool, _ right: Bool, _ lw: CGFloat = 0,
                      _ rw: CGFloat = 0, _ focus: Bool = false) -> CGFloat {
            MemoWeaverToolbarGeometry.minimumContentWidth(
                isNotePage: true, listVisible: list, rightVisible: right,
                focusMode: focus, preferredListWidth: lw,
                preferredRightWidth: rw, dividerThickness: 1)
        }
        near(minWidth(false, false), 630)
        near(minWidth(true, false), 678)
        near(minWidth(false, true), 809)
        near(minWidth(true, true), 1019)
        near(minWidth(false, false, 0, 0, true), 630)
        near(minWidth(true, true, 400, 550), 1384)
        near(minWidth(true, true, 10000, 10000), 1854) // clamped to saved pane bounds
        near(minWidth(true, true, -.infinity, .nan), 1019) // malformed preference fallback
        near(MemoWeaverToolbarGeometry.minimumContentWidth(
            isNotePage: false, listVisible: false, rightVisible: false,
            focusMode: false, preferredListWidth: 0, preferredRightWidth: 0,
            dividerThickness: 1), 970)
        precondition(minWidth(true, true) > minWidth(false, true))
        precondition(minWidth(true, true) > minWidth(true, false))
        precondition(MemoWeaverToolbarGeometry.dividerOrigins(
            listPaneStart: 255, auxiliaryPaneStart: 712, thickness: 1) == [254, 711])
        // Open a side pane while the main window is small: grow the WINDOW
        // before inserting the pane, not by stealing a saved pane's width.
        let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let closed = CGRect(x: 90, y: 100, width: 630, height: 700)
        let withList = MemoWeaverToolbarGeometry.expansionFrame(
            current: closed, requiredFrameWidth: minWidth(true, false), visibleFrame: display)
        near(withList.width, 678)
        near(withList.minX, 90)
        let withRight = MemoWeaverToolbarGeometry.expansionFrame(
            current: closed, requiredFrameWidth: minWidth(false, true), visibleFrame: display)
        near(withRight.width, 809)
        let both = MemoWeaverToolbarGeometry.expansionFrame(
            current: withList, requiredFrameWidth: minWidth(true, true), visibleFrame: display)
        near(both.width, 1019)
        // Enough existing width must NOT grow just because the pane toggles.
        near(MemoWeaverToolbarGeometry.expansionFrame(
            current: both, requiredFrameWidth: 678, visibleFrame: display).width, 1019)
        // Shift left rather than let the reopened pane go off the right edge.
        let againstRight = CGRect(x: 900, y: 100, width: 500, height: 700)
        let shifted = MemoWeaverToolbarGeometry.expansionFrame(
            current: againstRight, requiredFrameWidth: 810, visibleFrame: display)
        near(shifted.width, 810)
        near(shifted.minX, 630)
        // A screen narrower than the desired content width is an explicit
        // physical limitation. Fill its visible width; do not grow offscreen.
        let smallScreen = CGRect(x: 120, y: 0, width: 800, height: 800)
        let capped = MemoWeaverToolbarGeometry.expansionFrame(
            current: closed, requiredFrameWidth: 1019, visibleFrame: smallScreen)
        near(capped.width, 800)
        near(capped.minX, 120)
        let otherDisplay = CGRect(x: -1366, y: 0, width: 1366, height: 768)
        let onOther = CGRect(x: -900, y: 50, width: 650, height: 680)
        let moved = MemoWeaverToolbarGeometry.expansionFrame(
            current: onOther, requiredFrameWidth: 1100, visibleFrame: otherDisplay)
        near(moved.width, 1100)
        near(moved.minX, -1100)
        near(MemoWeaverToolbarGeometry.expansionFrame(
            current: closed, requiredFrameWidth: .nan, visibleFrame: display).width, 630)
        print("PASS v0.9.49: text/icon centers, four pane minima, auto-expansion, screen bounds")
    }
}
