import Foundation

// Window resizing and auxiliary-pane opening do not alter the user's saved
// sidebar widths. Only the editor absorbs surplus/deficit space, except when
// the window cannot physically accommodate the editor's minimum width.
// This model is Foundation-only so it can be tested without a macOS GUI.
enum MemoWeaverPinnedPaneLayout {
    enum Pane: Equatable { case list, editor, right }

    // NSSplitView must contain only actually visible panes. Keeping an
    // invisible pane in arrangedSubviews leaves stale divider geometry.
    static func visiblePaneOrder(listVisible: Bool, rightVisible: Bool) -> [Pane] {
        (listVisible ? [.list] : []) + [.editor] + (rightVisible ? [.right] : [])
    }

    static let listDefault: CGFloat = 245
    static let rightDefault: CGFloat = 340
    static let listMinimum: CGFloat = 175
    static let rightMinimum: CGFloat = 190
    static let editorMinimum: CGFloat = 240
    static let listMaximum: CGFloat = 420
    static let rightMaximum: CGFloat = 1_000

    // Capture a live divider width BEFORE inserting/removing any pane. The
    // previous implementation only captured a pane when IT was closing, so
    // resizing the list with the right pane closed was discarded on reopen.
    // Only uncompressed, physically possible sizes qualify for persistence.
    static func userWidthBeforeVisibilityChange(
        pane: Pane, observed: CGFloat, totalWidth: CGFloat,
        dividerThickness: CGFloat, listVisible: Bool, rightVisible: Bool,
        savedListWidth: CGFloat, savedRightWidth: CGFloat) -> CGFloat? {
        guard totalWidth.isFinite, totalWidth > 0,
              observed.isFinite else { return nil }
        let current = resolved(totalWidth: totalWidth, dividerThickness: dividerThickness,
                               listVisible: listVisible, rightVisible: rightVisible,
                               savedListWidth: savedListWidth, savedRightWidth: savedRightWidth)
        let preference: CGFloat
        let minimum: CGFloat
        let maximum: CGFloat
        let displayed: CGFloat
        switch pane {
        case .list:
            guard listVisible else { return nil }
            preference = savedListWidth > 0 && savedListWidth.isFinite ? savedListWidth : listDefault
            minimum = listMinimum; maximum = listMaximum; displayed = current.list
        case .right:
            guard rightVisible else { return nil }
            preference = savedRightWidth > 0 && savedRightWidth.isFinite ? savedRightWidth : rightDefault
            minimum = rightMinimum; maximum = rightMaximum; displayed = current.right
        case .editor: return nil
        }
        let target = min(maximum, max(minimum, preference))
        // If even the old saved value cannot fit, this is a temporary
        // compression, not a user width choice. Never persist it.
        guard displayed >= target - 0.5,
              observed >= minimum, observed <= maximum,
              abs(observed - target) > 0.5 else { return nil }
        // Require room for the editor, other visible pane and actual divider.
        let other = pane == .list ? current.right : current.list
        guard observed + other + editorMinimum + current.divider <= totalWidth + 0.5 else { return nil }
        return observed
    }

    struct Widths {
        let list: CGFloat
        let editor: CGFloat
        let right: CGFloat
        let divider: CGFloat
        var total: CGFloat { list + editor + right + divider }
    }

    static func resolved(totalWidth: CGFloat, dividerThickness: CGFloat,
                         listVisible: Bool, rightVisible: Bool,
                         savedListWidth: CGFloat, savedRightWidth: CGFloat) -> Widths {
        let width = max(0, totalWidth.isFinite ? totalWidth : 0)
        let dividerCount = (listVisible ? 1 : 0) + (rightVisible ? 1 : 0)
        // NSViewRepresentable is created with a 0pt frame before its first
        // actual layout. Do not allocate 2pt of dividers inside a 0pt frame.
        let divider = min(width, CGFloat(dividerCount) *
                          max(0, dividerThickness.isFinite ? dividerThickness : 0))
        let usable = max(0, width - divider)
        func preference(_ saved: CGFloat, default fallback: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
            let candidate = saved > 0 && saved.isFinite ? saved : fallback
            return min(maximum, max(minimum, candidate))
        }
        let desiredList = listVisible ? preference(savedListWidth, default: listDefault,
                                                  minimum: listMinimum, maximum: listMaximum) : 0
        let desiredRight = rightVisible ? preference(savedRightWidth, default: rightDefault,
                                                    minimum: rightMinimum, maximum: rightMaximum) : 0
        var list = desiredList
        var right = desiredRight
        // Normal case: the saved widths are exact. When impossible, preserve
        // the list first and reduce the auxiliary width toward its minimum.
        var shortage = max(0, list + right + editorMinimum - usable)
        if shortage > 0 && rightVisible {
            let reduction = min(shortage, max(0, right - rightMinimum))
            right -= reduction
            shortage -= reduction
        }
        if shortage > 0 && listVisible {
            let reduction = min(shortage, max(0, list - listMinimum))
            list -= reduction
            shortage -= reduction
        }
        // Extreme/transient undersized frame: fit the available width without
        // producing negative editor frames or rewriting persisted preferences.
        if shortage > 0 && rightVisible {
            let reduction = min(shortage, right)
            right -= reduction
            shortage -= reduction
        }
        if shortage > 0 && listVisible {
            let reduction = min(shortage, list)
            list -= reduction
        }
        return Widths(list: list, editor: max(0, usable - list - right),
                      right: right, divider: divider)
    }
}


// Quick editor/auxiliary width presets. The note-list pane is excluded from
// the ratio and the existing one-pixel native dividers remain in AppKit.
// A preset changes only the saved AUXILIARY width; a user's manual splitter
// drag and future window resizing remain under the existing NSSplitView rules.
enum MemoWeaverPaneRatioPreset: String, CaseIterable, Identifiable {
    case editor70, editor60, equal
    var id: String { rawValue }
    var title: String {
        switch self {
        case .editor70: return "편집 70% · 보조 30%"
        case .editor60: return "편집 60% · 보조 40%"
        case .equal: return "편집 50% · 보조 50%"
        }
    }
    var rightFraction: CGFloat {
        switch self {
        case .editor70: return 0.30
        case .editor60: return 0.40
        case .equal: return 0.50
        }
    }
    var compactRatio: String {
        switch self {
        case .editor70: return "70:30"
        case .editor60: return "60:40"
        case .equal: return "50:50"
        }
    }
    // Cycle from the actual visible split ratio, including a manually dragged
    // divider. The next click always produces one of the three presets.
    static func next(afterEditorPercent value: Int?) -> Self {
        guard let value else { return .editor60 }
        if value < 58 { return .editor60 }
        if value < 68 { return .editor70 }
        return .equal
    }
}

// Read-only native split measurement. The text on the footer must reflect the
// live editor:auxiliary proportions even after manual dragging/window resizing.
// No persistence or resizing is performed by this calculation.
extension MemoWeaverPinnedPaneLayout {
    static func editorPercent(editorWidth: CGFloat, rightWidth: CGFloat) -> Int? {
        guard editorWidth.isFinite, rightWidth.isFinite,
              editorWidth > 0, rightWidth > 0 else { return nil }
        let sum = editorWidth + rightWidth
        guard sum.isFinite, sum > 0 else { return nil }
        return min(100, max(0, Int((100 * editorWidth / sum).rounded())))
    }
}

struct MemoWeaverPaneRatioRequest: Equatable {
    let id: UUID
    let preset: MemoWeaverPaneRatioPreset
}

extension MemoWeaverPinnedPaneLayout {
    // Fails closed if an external resize leaves inadequate width for both
    // minimums. Never save an impossible/compressed right-pane preference.
    static func rightWidth(for preset: MemoWeaverPaneRatioPreset,
                           combinedWidth: CGFloat) -> CGFloat? {
        guard combinedWidth.isFinite,
              combinedWidth >= editorMinimum + rightMinimum else { return nil }
        let maximum = min(rightMaximum, combinedWidth - editorMinimum)
        return min(maximum, max(rightMinimum, combinedWidth * preset.rightFraction))
    }
}
