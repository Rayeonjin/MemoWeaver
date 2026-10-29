import Foundation

// Foundation-only layout tests. No window, user database or WebKit required.
@main
struct NativeSplitSizingV0920Smoke {
    static func approx(_ lhs: CGFloat, _ rhs: CGFloat, tolerance: CGFloat = 0.01,
                       file: StaticString = #file, line: UInt = #line) {
        assert(abs(lhs - rhs) <= tolerance, "Expected \(lhs) ~= \(rhs)", file: file, line: line)
    }

    static func main() {
        for nav: CGFloat in [135, 156, 205] {
            var previous: NoteWorkspaceLayout.Widths?
            for window in 970...1440 {
                let detail = CGFloat(window) - nav
                let w = NoteWorkspaceLayout.widths(availableWidth: detail,
                                  listVisible: true, rightPanelVisible: true)
                approx(w.total, detail)
                assert(w.list >= NoteWorkspaceLayout.minimumListWidth)
                assert(w.editor >= NoteWorkspaceLayout.minimumEditorWidth)
                assert(w.right >= NoteWorkspaceLayout.minimumRightWidth)
                if let old = previous {
                    // No automatic list-to-popover switch or 190pt editor jump
                    // when the window crosses 1240/1241pt.
                    assert(abs(w.editor - old.editor) <= 1.01)
                    assert(abs(w.list - old.list) <= 1.01)
                    assert(abs(w.right - old.right) <= 1.01)
                }
                previous = w
            }
        }

        let wide: CGFloat = 1320 - 156
        let initial = NoteWorkspaceLayout.widths(availableWidth: wide,
                                   listVisible: true, rightPanelVisible: true)
        let rightDrag = NoteWorkspaceLayout.widths(availableWidth: wide,
                                   listVisible: true, rightPanelVisible: true,
                                   preferredListWidth: initial.list,
                                   preferredRightWidth: initial.right + 195,
                                   resizing: .right)
        approx(rightDrag.list, initial.list)
        approx(rightDrag.right - initial.right, 195)
        approx(initial.editor - rightDrag.editor, 195)
        // Dragging the list never changes the right pane size.
        let listDrag = NoteWorkspaceLayout.widths(availableWidth: wide,
                                   listVisible: true, rightPanelVisible: true,
                                   preferredListWidth: initial.list + 85,
                                   preferredRightWidth: initial.right,
                                   resizing: .list)
        approx(listDrag.list - initial.list, 85)
        approx(listDrag.right, initial.right)
        approx(initial.editor - listDrag.editor, 85)
        let rightSmaller = NoteWorkspaceLayout.widths(availableWidth: wide,
                                   listVisible: true, rightPanelVisible: true,
                                   preferredListWidth: initial.list,
                                   preferredRightWidth: initial.right - 95,
                                   resizing: .right)
        approx(initial.right - rightSmaller.right, 95)
        assert(NoteWorkspaceLayout.maximumRightWidth > wide * 0.37)
        assert(NoteWorkspaceLayout.gripWidth >= 1) // Native AppKit divider, not a custom hit target

        // Even at 970pt, the right divider must have meaningful travel.
        for nav: CGFloat in [135, 156, 205] {
            let detail: CGFloat = 970 - nav
            let original = NoteWorkspaceLayout.widths(availableWidth: detail,
                             listVisible: true, rightPanelVisible: true)
            let expanded = NoteWorkspaceLayout.widths(availableWidth: detail,
                             listVisible: true, rightPanelVisible: true,
                             preferredListWidth: original.list,
                             preferredRightWidth: 1_000, resizing: .right)
            assert(expanded.right - original.right >= (nav == 156 ? 90 : 60),
                   "Resize handle still constrained at narrow width/nav=\(nav)")
            approx(expanded.list, original.list)
        }

        // Narrow-window policy is explicit: the list stays in the same inline
        // layout until the user presses the list toggle. No popover.
        let narrow: CGFloat = 970 - 205
        let normal = NoteWorkspaceLayout.widths(availableWidth: narrow,
                                   listVisible: true, rightPanelVisible: true)
        let hiddenList = NoteWorkspaceLayout.widths(availableWidth: narrow,
                                   listVisible: false, rightPanelVisible: true)
        assert(normal.list > 0)
        assert(hiddenList.list == 0)
        assert(hiddenList.editor > normal.editor + 90)
        approx(normal.total, narrow)
        approx(hiddenList.total, narrow)
        let noRight = NoteWorkspaceLayout.widths(availableWidth: narrow,
                                   listVisible: true, rightPanelVisible: false)
        assert(noRight.right == 0)
        assert(noRight.editor > normal.editor)
        approx(noRight.total, narrow)
        let onlyEditor = NoteWorkspaceLayout.widths(availableWidth: narrow,
                                   listVisible: false, rightPanelVisible: false)
        approx(onlyEditor.editor, narrow)
        approx(onlyEditor.total, narrow)
        // Persisting a 480pt width and reopening at the same geometry works.
        let restored = NoteWorkspaceLayout.widths(availableWidth: wide,
                                   listVisible: true, rightPanelVisible: true,
                                   preferredRightWidth: 480)
        approx(restored.right, 480)
        // Transient undersized or invalid geometry cannot generate NaNs.
        for width: CGFloat in [0, 10, 400, 740, .nan, .infinity, -.infinity] {
            let w = NoteWorkspaceLayout.widths(availableWidth: width,
                                       listVisible: true, rightPanelVisible: true)
            assert(w.list.isFinite && w.editor.isFinite && w.right.isFinite)
            assert(w.list >= 0 && w.right >= 0 && w.editor >= 0)
        }
        print("PASS v0.9.20 native-split ideals: continuous 970-1440pt (3 nav widths), large drags, adjacent-only resizing, stable manual list, width persistence, finite geometry")
    }
}
func escapeHTML(_ text: String) -> String { text }
