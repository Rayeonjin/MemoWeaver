import AppKit
import Foundation

// Compile and run with AppKit on a real Mac. This smoke verifies the toolbar
// item contract and that tracking separators can be attached to an NSSplitView.
// It is NOT a substitute for visual GUI QA in the shipping SwiftUI Window.
@main
struct NativeWindowV0942Smoke {
    static func main() {
        func state(_ list: Bool, _ right: Bool) -> MemoWeaverToolbarSnapshot {
            MemoWeaverToolbarSnapshot(isNotePage: true, listVisible: list,
                rightVisible: right, focusMode: false, hasCurrentNote: true,
                noteID: "test", noteTitle: "테스트", notePinned: false,
                noteTrashed: false, isTrashPage: false, selectedRightTab: "preview")
        }
        let ids = MemoWeaverToolbarItems.self
        _ = ids
        for list in [false, true] {
            for right in [false, true] {
                let order = MemoWeaverToolbarItems.order(state(list, right), tracking: true)
                let left = order.firstIndex(of: MemoWeaverToolbarItems.listToggle)!
                let title = order.firstIndex(of: MemoWeaverToolbarItems.editorTitle)!
                let rightToggle = order.firstIndex(of: MemoWeaverToolbarItems.rightToggle)!
                assert(left < title && title < rightToggle)
                assert(order.filter { $0 == MemoWeaverToolbarItems.listToggle }.count == 1)
                assert(order.filter { $0 == MemoWeaverToolbarItems.rightToggle }.count == 1)
                assert(order.contains(MemoWeaverToolbarItems.listBoundary) == list)
                assert(order.contains(MemoWeaverToolbarItems.rightBoundary) == right)
                assert(order.contains(MemoWeaverToolbarItems.rightTabs) == right)
                if list {
                    assert(order.firstIndex(of: MemoWeaverToolbarItems.listBoundary)! < left)
                }
                if right {
                    assert(rightToggle < order.firstIndex(of: MemoWeaverToolbarItems.rightBoundary)!)
                }
                assert(order[title + 1] == .flexibleSpace)
            }
        }

        // Compile-time AppKit API regression: currentEditor() is NSText?,
        // and the concrete field editor implements NSTextInputClient.
        func isComposing(_ field: NSTextField) -> Bool {
            guard let editor = field.currentEditor() as? NSTextView else { return false }
            return editor.hasMarkedText()
        }
        assert(!isComposing(NSTextField(frame: .zero)))

        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1200, height: 740),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        let split = NSSplitView(frame: NSRect(x: 52, y: 0, width: 1148, height: 700))
        split.isVertical = true
        let list = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 700))
        let editor = NSView(frame: NSRect(x: 261, y: 0, width: 520, height: 700))
        let right = NSView(frame: NSRect(x: 782, y: 0, width: 366, height: 700))
        for view in [list, editor, right] { split.addArrangedSubview(view) }
        window.contentView?.addSubview(split)
        let tracking = NSTrackingSeparatorToolbarItem(
            identifier: MemoWeaverToolbarItems.rightBoundary, splitView: split, dividerIndex: 1)
        assert(tracking.splitView === split && tracking.dividerIndex == 1)
        tracking.dividerIndex = 0
        assert(tracking.dividerIndex == 0)
        print("PASS native toolbar four pane states, rightmost toggle ordering, AppKit divider tracking")
        window.close()
    }
}
