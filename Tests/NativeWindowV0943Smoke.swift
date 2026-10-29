import AppKit
import Foundation

// AppKit-only smoke. Native toolbar registration must never be mutated when
// toggling visible panes. This does NOT substitute for an actual GUI click test.
@main struct NativeWindowV0943Smoke {
    static func main() {
        func snapshot(_ list: Bool, _ right: Bool) -> MemoWeaverToolbarSnapshot {
            MemoWeaverToolbarSnapshot(isNotePage: true, listVisible: list,
                rightVisible: right, focusMode: false, hasCurrentNote: true,
                noteID: "test", noteTitle: "테스트", notePinned: false,
                noteTrashed: false, isTrashPage: false, selectedRightTab: "preview")
        }
        for _ in 0..<100 {
            for list in [false, true] {
                for right in [false, true] {
                    let items = MemoWeaverToolbarItems.order(snapshot(list, right))
                    precondition(items == [MemoWeaverToolbarItems.workspace])
                }
            }
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 1200, height: 800),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.toolbarStyle = .unifiedCompact
        let toolbar = NSToolbar(identifier: MemoWeaverToolbarItems.toolbarID)
        toolbar.autosavesConfiguration = false
        window.toolbar = toolbar
        let split = NSSplitView(frame: .init(x: 52, y: 0, width: 1148, height: 700))
        split.isVertical = true
        let list = NSView(frame: .init(x: 0, y: 0, width: 260, height: 700))
        let editor = NSView(frame: .init(x: 260, y: 0, width: 550, height: 700))
        let aux = NSView(frame: .init(x: 810, y: 0, width: 338, height: 700))
        split.addArrangedSubview(list)
        split.addArrangedSubview(editor)
        split.addArrangedSubview(aux)
        window.contentView?.addSubview(split)
        for _ in 0..<20 {
            list.removeFromSuperview()
            split.adjustSubviews()
            split.insertArrangedSubview(list, at: 0)
            split.adjustSubviews()
            aux.removeFromSuperview()
            split.adjustSubviews()
            split.addArrangedSubview(aux)
            split.adjustSubviews()
        }
        precondition(split.arrangedSubviews.count == 3)
        precondition(toolbar.itemIdentifiers.isEmpty, "Synthetic toolbar should remain unchanged")
        print("PASS native: immutable toolbar item order, repeated NSSplitView panel removal/reinsert")
        window.close()
    }
}
