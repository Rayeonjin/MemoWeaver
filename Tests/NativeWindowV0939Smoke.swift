import AppKit
import SwiftUI

// Execute ONLY on a Mac. Unlike HTML concept previews, this mounts a real
// native NSSplitView inside a real NSWindow and validates tracked titlebar
// boundaries when either pane is closed/reopened.
@MainActor
final class ZoneState: ObservableObject {
    @Published var listVisible = true
    @Published var rightVisible = true
}

struct ZoneRoot: View {
    @ObservedObject var state: ZoneState

    var body: some View {
        HStack(spacing: 0) {
            Color(nsColor: .controlBackgroundColor).frame(width: 52)
            Divider()
            MemoWeaverPinnedSplitView(
                list: Text("메모 목록").frame(maxWidth: .infinity, maxHeight: .infinity),
                editor: Text("편집창").frame(maxWidth: .infinity, maxHeight: .infinity),
                right: Text("보조창").frame(maxWidth: .infinity, maxHeight: .infinity),
                listVisible: state.listVisible, rightVisible: state.rightVisible,
                listPreferred: 280, rightPreferred: 300,
                saveListWidth: { _ in }, saveRightWidth: { _ in })
        }
        .background(MemoWeaverNativeWindowChrome(snapshot: MemoWeaverToolbarSnapshot(
            listVisible: state.listVisible, rightVisible: state.rightVisible,
            focusMode: false, isNotePage: true, hasCurrentNote: true))
            .frame(width: 1, height: 1))
    }
}

@MainActor
@main
struct NativeWindowV0939Smoke {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let state = ZoneState()
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 1160, height: 740),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.contentView = NSHostingView(rootView: ZoneRoot(state: state))
        window.makeKeyAndOrderFront(nil)
        func settle() {
            window.layoutIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.28))
            window.layoutIfNeeded()
        }
        func splitView(_ node: NSView) -> NSSplitView? {
            if let split = node as? NSSplitView,
               split.identifier?.rawValue == "MemoWeaver.notes.pinnedSplit" { return split }
            for child in node.subviews {
                if let found = splitView(child) { return found }
            }
            return nil
        }
        func verify(_ list: Bool, _ right: Bool) {
            settle()
            guard let split = window.contentView.flatMap(splitView),
                  let toolbar = window.toolbar else { fatalError("Missing real NSSplitView/NSToolbar") }
            let identifiers = toolbar.items.map(\.itemIdentifier)
            let items = MemoWeaverToolbarItems.self
            precondition(identifiers.contains(items.newNote), "New note must be available")
            precondition(identifiers.contains(items.focus), "Focus mode must stay accessible")
            precondition(identifiers.contains(items.listBoundary) == list,
                         "List/editor titlebar boundary must exactly match visibility")
            precondition(identifiers.contains(items.rightBoundary) == right,
                         "Editor/aux titlebar boundary must exactly match visibility")
            precondition(!identifiers.contains(NSToolbarItem.Identifier("MemoWeaver.toolbar.paneTabs")),
                         "Auxiliary tabs belong INSIDE auxiliary pane")
            precondition(!identifiers.contains(NSToolbarItem.Identifier("MemoWeaver.toolbar.right")),
                         "Right toggle belongs at upper-RIGHT of editor TITLE")
            precondition(!identifiers.contains(NSToolbarItem.Identifier("MemoWeaver.toolbar.list")),
                         "List toggle belongs at upper-LEFT of editor TITLE")
            for (id, divider) in [(items.listBoundary, 0),
                                  (items.rightBoundary, list ? 1 : 0)] where identifiers.contains(id) {
                guard let tracker = toolbar.items.first(where: { $0.itemIdentifier == id })
                    as? NSTrackingSeparatorToolbarItem else { fatalError("Must use native tracked separator") }
                precondition(tracker.splitView === split, "Tracking must target the actual native pane split")
                precondition(tracker.dividerIndex == divider, "Wrong divider after visibility change")
            }
            precondition(split.arrangedSubviews.count == 1 + (list ? 1 : 0) + (right ? 1 : 0),
                         "Only visible panes may occupy native split")
            precondition(window.toolbarStyle == .unifiedCompact, "Native unified toolbar style")
            precondition(window.styleMask.contains(.fullSizeContentView), "Full-height sidebar")
        }
        verify(true, true)
        state.rightVisible = false
        verify(true, false)
        state.listVisible = false
        state.rightVisible = true
        verify(false, true)
        state.rightVisible = false
        verify(false, false)
        state.listVisible = true
        state.rightVisible = true
        verify(true, true)
        window.orderOut(nil)
        window.close()
        print("PASS v0.9.39 actual AppKit: titlebar boundaries follow list/editor/right split through all 4 states")
    }
}
