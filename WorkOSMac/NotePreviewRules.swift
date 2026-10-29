import Foundation

// A formatted note or one with extension blocks opens the preview-to-side by default.
// Plain text notes remain uncluttered unless the user explicitly opens preview.
enum NotePreviewRules {
    static func autoOpen(bodyHTML: String, blocks: [WorkBlock], isMarkdown: Bool = false) -> Bool {
        if isMarkdown { return true }
        if !blocks.isEmpty { return true }
        return bodyHTML.range(of: #"<(h[1-6]|table|pre|blockquote|ul|ol)\b"#,
                              options: [.regularExpression, .caseInsensitive]) != nil
    }
}

// Routing for the unified right panel. Kept Foundation-only so switching
// behavior can be tested without AppKit or a user database.
enum NoteSidePaneTab: String, CaseIterable {
    case preview
    case reference
    case memory
    case assistant
}

enum NoteSidePaneRules {
    static func isVisible(override: Bool?, tab: NoteSidePaneTab,
                          bodyHTML: String, blocks: [WorkBlock], isMarkdown: Bool = false) -> Bool {
        if let override { return override }
        return tab == .preview && NotePreviewRules.autoOpen(bodyHTML: bodyHTML, blocks: blocks, isMarkdown: isMarkdown)
    }

    // The small activity-rail layout favors writing. It leaves the right pane
    // closed until explicitly requested, without mutating the old preference.
    // Legacy navigation still follows the original Markdown auto-preview rule.
    static func isVisibleForLayout(preference: String, compactNavigation: Bool,
                                   tab: NoteSidePaneTab, bodyHTML: String,
                                   blocks: [WorkBlock], isMarkdown: Bool = false) -> Bool {
        let override = visibilityOverride(preference: preference)
        if compactNavigation && override == nil { return false }
        return isVisible(override: override, tab: tab, bodyHTML: bodyHTML,
                         blocks: blocks, isMarkdown: isMarkdown)
    }

    // An explicit user choice always wins across note selection. In particular,
    // false must NOT turn into nil (nil would auto-open Markdown previews).
    static func overrideAfterNoteChange(current: Bool?, tab: NoteSidePaneTab) -> Bool? {
        current
    }

    // UserDefaults persists only the explicit preference, never per-note state.
    static func visibilityOverride(preference: String) -> Bool? {
        switch preference {
        case "open": return true
        case "closed": return false
        default: return nil
        }
    }
}

// All three column widths are resolved from the *real* detail width. A
// layout ideals are hints for the native HSplitView, not pixel-fixed
// sizes or manual drags. There is no automatic list-to-popover breakpoint:
// the user decides whether the note list is shown.
enum NoteWorkspaceLayout {
    enum ResizeTarget {
        case none, list, right
    }

    // Approximate native divider allowance for ideal-width calculations.
    // Real NSSplitView owns its divider width and interaction.
    static let gripWidth: CGFloat = 1
    static let defaultListWidth: CGFloat = 245
    static let defaultRightWidth: CGFloat = 340
    static let minimumListWidth: CGFloat = 175
    static let minimumEditorWidth: CGFloat = 240
    static let minimumRightWidth: CGFloat = 190
    static let maximumListWidth: CGFloat = 420
    static let maximumRightWidth: CGFloat = 1_000

    // Smooth defaults: a narrow window gets thinner columns, not a sudden
    // popover or a hard 1085pt switch. A stored positive width overrides
    // these recommendations until the user double-clicks to reset.
    static func recommendedListWidth(availableWidth: CGFloat) -> CGFloat {
        min(defaultListWidth, max(minimumListWidth,
            205 + (availableWidth - 765) * 0.17))
    }

    static func recommendedRightWidth(availableWidth: CGFloat) -> CGFloat {
        min(defaultRightWidth, max(minimumRightWidth, availableWidth * 0.29))
    }

    struct Widths {
        let list: CGFloat
        let editor: CGFloat
        let right: CGFloat
        let grip: CGFloat

        var total: CGFloat { list + editor + right + grip }
    }

    /// Produces initial width ideals only. During mouse dragging AppKit
    /// owns positions and minimum/maximum constraints. Bounds scale only for
    /// transient undersized GeometryReader measurements (970pt window min).
    static func widths(availableWidth: CGFloat,
                       listVisible: Bool,
                       rightPanelVisible: Bool,
                       preferredListWidth: CGFloat = 0,
                       preferredRightWidth: CGFloat = 0,
                       resizing: ResizeTarget = .none) -> Widths {
        let fullWidth = max(0, availableWidth.isFinite ? availableWidth : 0)
        let gripCount = (listVisible ? 1 : 0) + (rightPanelVisible ? 1 : 0)
        let grip = min(fullWidth, CGFloat(gripCount) * gripWidth)
        let content = max(0, fullWidth - grip)

        let requestedMinimum = minimumEditorWidth +
            (listVisible ? minimumListWidth : 0) +
            (rightPanelVisible ? minimumRightWidth : 0)
        let scale = min(1, content / max(1, requestedMinimum))
        let editorMinimum = minimumEditorWidth * scale
        let listMinimum = listVisible ? minimumListWidth * scale : 0
        let rightMinimum = rightPanelVisible ? minimumRightWidth * scale : 0

        func bounded(_ value: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
            let safeValue = value.isFinite ? value : minimum
            return min(maximum, max(minimum, safeValue))
        }

        let listPreference = preferredListWidth > 0 ? preferredListWidth :
            recommendedListWidth(availableWidth: fullWidth)
        let rightPreference = preferredRightWidth > 0 ? preferredRightWidth :
            recommendedRightWidth(availableWidth: fullWidth)

        let list: CGFloat
        let right: CGFloat
        if resizing == .list {
            // A list-grip drag affects only the list and its adjacent editor.
            right = rightPanelVisible
                ? bounded(rightPreference, minimum: rightMinimum,
                          maximum: max(rightMinimum,
                                       min(maximumRightWidth, content - editorMinimum - listMinimum)))
                : 0
            list = listVisible
                ? bounded(listPreference, minimum: listMinimum,
                          maximum: max(listMinimum,
                                       min(maximumListWidth, content - editorMinimum - right)))
                : 0
        } else {
            // Normal resize and right-grip drags keep the list in place.
            list = listVisible
                ? bounded(listPreference, minimum: listMinimum,
                          maximum: max(listMinimum,
                                       min(maximumListWidth, content - editorMinimum - rightMinimum)))
                : 0
            right = rightPanelVisible
                ? bounded(rightPreference, minimum: rightMinimum,
                          maximum: max(rightMinimum,
                                       min(maximumRightWidth, content - editorMinimum - list)))
                : 0
        }
        let editor = max(0, content - list - right)
        return Widths(list: list, editor: editor, right: right, grip: grip)
    }
}
