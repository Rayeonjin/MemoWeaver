import Foundation

@main struct ToolbarGeometryV0948Smoke {
    static func main() {
        func near(_ a: CGFloat, _ b: CGFloat) {
            precondition(abs(a - b) < 0.00001, "\(a) != \(b)")
        }
        // Every native control has the same optical alignment box.
        near(MemoWeaverToolbarGeometry.canvasHeight, 34)
        near(MemoWeaverToolbarGeometry.controlHeight, 28)
        near(MemoWeaverToolbarGeometry.controlWidth, 30)
        near(MemoWeaverToolbarGeometry.verticalOrigin, 3)
        near(MemoWeaverToolbarGeometry.verticalOrigin + MemoWeaverToolbarGeometry.controlHeight / 2, 17)
        let divider: CGFloat = 1
        // All four visibility states; list/auxiliary coordinates are in the
        // persistent canvas coordinate system after conversion from the split.
        precondition(MemoWeaverToolbarGeometry.dividerOrigins(
            listPaneStart: nil, auxiliaryPaneStart: nil, thickness: divider).isEmpty)
        let list = MemoWeaverToolbarGeometry.dividerOrigins(
            listPaneStart: 260, auxiliaryPaneStart: nil, thickness: divider)
        precondition(list == [259])
        let right = MemoWeaverToolbarGeometry.dividerOrigins(
            listPaneStart: nil, auxiliaryPaneStart: 730, thickness: divider)
        precondition(right == [729])
        let both = MemoWeaverToolbarGeometry.dividerOrigins(
            listPaneStart: 260, auxiliaryPaneStart: 730, thickness: divider)
        precondition(both == [259, 729])
        // No rail boundary at x=52 is ever supplied or drawn.
        precondition(!both.contains(52))
        // Support real split divider widths rather than a hard-coded 1pt.
        let thick = MemoWeaverToolbarGeometry.dividerOrigins(
            listPaneStart: 261.5, auxiliaryPaneStart: 730.5, thickness: 1.5)
        precondition(thick == [260, 729])
        precondition(MemoWeaverToolbarGeometry.dividerOrigins(
            listPaneStart: 260, auxiliaryPaneStart: 730, thickness: 0).isEmpty)
        precondition(MemoWeaverToolbarGeometry.dividerOrigins(
            listPaneStart: .infinity, auxiliaryPaneStart: nil, thickness: divider).isEmpty)
        print("PASS v0.9.48 toolbar geometry: common 28pt controls, 4 pane states, no rail rule, live thickness")
    }
}
