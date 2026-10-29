import Foundation

/// Foundation-only geometry for the persistent AppKit toolbar canvas.
/// This is independent from NSSplitView's persisted width/resize algorithm.
/// It can be typechecked and tested on Linux, before the Mac GUI acceptance.
enum MemoWeaverToolbarGeometry {
    static let canvasHeight: CGFloat = 34
    static let controlHeight: CGFloat = 28
    static let controlWidth: CGFloat = 30
    static var verticalOrigin: CGFloat { (canvasHeight - controlHeight) / 2 }

    // NSTextFieldCell renders a 13pt one-line title at the top of a 28pt
    // frame, unlike the vertically centered NSButton image.  Measured against
    // the actual v0.9.48 Mac screenshot: title ink ~y17, glyphs ~y23.
    // Use a one-line text fitting box centered inside the 34pt canvas, while
    // buttons and segmented controls retain their native 28pt hit targets.
    static let titleTextHeight: CGFloat = 19
    static var titleTextOrigin: CGFloat { (canvasHeight - titleTextHeight) / 2 }

    // The user can shrink the WINDOW only while the toolbar's key controls
    // remain visible.  These figures are per-pane *usable* widths. The side
    // preferences are still owned by NSSplitView / UserDefaults; this geometry
    // never saves a compressed preference or changes the split algorithm.
    static let railWidth: CGFloat = 52
    static let trailingChromeAllowance: CGFloat = 24
    static let minimumEditorWithList: CGFloat = 356
    static let minimumEditorWithoutList: CGFloat = 392 // new-note button is in editor
    static let minimumNotesWindow: CGFloat = 630
    static let minimumOtherPageWindow: CGFloat = 970
    static let minimumContentHeight: CGFloat = 640

    static func minimumContentWidth(isNotePage: Bool,
                                    listVisible: Bool, rightVisible: Bool,
                                    focusMode: Bool, preferredListWidth: CGFloat,
                                    preferredRightWidth: CGFloat,
                                    dividerThickness: CGFloat) -> CGFloat {
        if !isNotePage { return minimumOtherPageWindow }
        let list = listVisible ? safePaneWidth(preferredListWidth, fallback: 245,
                                                minimum: 175, maximum: 420) : 0
        let right = rightVisible ? safePaneWidth(preferredRightWidth, fallback: 340,
                                                  minimum: 190, maximum: 1_000) : 0
        let editor = listVisible ? minimumEditorWithList : minimumEditorWithoutList
        let rail = focusMode ? 0 : railWidth
        let dividerCount = (listVisible ? 1 : 0) + (rightVisible ? 1 : 0)
        let divider = max(0, dividerThickness.isFinite ? dividerThickness : 1)
        return ceil(max(minimumNotesWindow,
                        rail + list + editor + right + CGFloat(dividerCount) * divider
                        + trailingChromeAllowance))
    }

    private static func safePaneWidth(_ value: CGFloat, fallback: CGFloat,
                                      minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        let candidate = value.isFinite && value > 0 ? value : fallback
        return min(maximum, max(minimum, candidate))
    }

    // Window frame planning is Foundation-only and has no AppKit side effects.
    // A reopened panel must NOT consume the editor's readable width. Grow the
    // outer WINDOW first, retaining its left edge when there is screen room.
    // If the right edge would leave the display, shift the window left; never
    // extend a normal window beyond the screen's visible width.
    static func expansionFrame(current: CGRect, requiredFrameWidth: CGFloat,
                               visibleFrame: CGRect?) -> CGRect {
        guard current.width.isFinite, current.width > 0,
              requiredFrameWidth.isFinite, requiredFrameWidth > current.width + 0.5 else {
            return current
        }
        let usableScreen: CGRect? = {
            guard let visibleFrame, visibleFrame.width.isFinite,
                  visibleFrame.width > 0, visibleFrame.minX.isFinite,
                  visibleFrame.maxX.isFinite else { return nil }
            return visibleFrame
        }()
        let width = ceil(min(requiredFrameWidth, usableScreen?.width ?? requiredFrameWidth))
        guard width > current.width + 0.5 else { return current }
        var result = current
        result.size.width = width
        if let screen = usableScreen {
            result.origin.x = max(screen.minX, min(current.minX, screen.maxX - width))
        }
        return result
    }

    // Inputs are the LEADING edge of the next arranged subview, in titlebar
    // canvas coordinates. No rail start is accepted: never draw that boundary.
    static func dividerOrigins(listPaneStart: CGFloat?, auxiliaryPaneStart: CGFloat?,
                               thickness: CGFloat) -> [CGFloat] {
        guard thickness > 0 else { return [] }
        var xs: [CGFloat] = []
        if let listPaneStart, listPaneStart.isFinite {
            xs.append(listPaneStart - thickness)
        }
        if let auxiliaryPaneStart, auxiliaryPaneStart.isFinite {
            xs.append(auxiliaryPaneStart - thickness)
        }
        return xs
    }
}
