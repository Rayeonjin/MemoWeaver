import Foundation

@main
struct ActivityRailV0921Smoke {
    static func main() {
        let html = "<h1>Preview</h1>"
        func visible(_ mode: Bool, _ preference: String, _ tab: NoteSidePaneTab = .preview) -> Bool {
            NoteSidePaneRules.isVisibleForLayout(
                preference: preference, compactNavigation: mode,
                tab: tab, bodyHTML: html, blocks: [], isMarkdown: true)
        }
        assert(!visible(true, "automatic"), "compact default must not open preview")
        assert(visible(false, "automatic"), "legacy Markdown preview policy must persist")
        assert(visible(true, "open"), "explicit open must be preserved")
        assert(!visible(true, "closed"), "explicit close must be preserved")
        assert(visible(false, "open", .reference))
        assert(!visible(true, "automatic", .reference))
        assert(visible(true, "open", .memory))

        // The fixed rail costs 52pt, versus the former ~156pt navigation bar.
        // The native HSplitView remains the only resizable region, and the
        // two optional columns never disappear at an arbitrary breakpoint.
        let rail: CGFloat = 53
        for width in stride(from: CGFloat(970), through: CGFloat(1440), by: 1) {
            for showRight in [false, true] {
                let s = NoteWorkspaceLayout.widths(
                    availableWidth: width - rail,
                    listVisible: true, rightPanelVisible: showRight)
                assert(s.list >= NoteWorkspaceLayout.minimumListWidth)
                assert(s.editor >= NoteWorkspaceLayout.minimumEditorWidth)
                if showRight { assert(s.right >= NoteWorkspaceLayout.minimumRightWidth) }
                else { assert(s.right == 0) }
                assert(abs(s.total - (width - rail)) < 0.01)
            }
        }
        let a = NoteWorkspaceLayout.widths(availableWidth: 1240 - rail,
                    listVisible: true, rightPanelVisible: true)
        let b = NoteWorkspaceLayout.widths(availableWidth: 1241 - rail,
                    listVisible: true, rightPanelVisible: true)
        assert(abs(a.editor-b.editor) <= 1.1)
        let focus = NoteWorkspaceLayout.widths(availableWidth: 970 - rail,
                    listVisible: false, rightPanelVisible: false)
        assert(focus.list == 0 && focus.right == 0 && focus.editor >= 900)
        print("PASS v0.9.21: compact preview default, explicit preferences, legacy fallback, 970-1440pt native split constraints and focus width")
    }
}

func escapeHTML(_ input: String) -> String { input }
