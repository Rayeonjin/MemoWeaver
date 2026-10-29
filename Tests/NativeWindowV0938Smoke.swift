import AppKit
import SwiftUI

// Run on a REAL Mac. Unlike HTML mockups or source-phrase checks, this builds
// an NSWindow and inspects the installed toolbar, notifications, and state.
@main
struct NativeWindowV0938Smoke {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 1120, height: 720),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        let initial = MemoWeaverToolbarSnapshot(listVisible: true, rightVisible: true,
                                                 focusMode: false, isNotePage: true,
                                                 hasCurrentNote: true, rightTab: "preview")
        let host = NSHostingView(rootView: MemoWeaverNativeWindowChrome(snapshot: initial)
                                 .frame(width: 1, height: 1))
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        window.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))

        guard let toolbar = window.toolbar else { fatalError("Missing real NSToolbar") }
        precondition(toolbar.identifier == MemoWeaverToolbarItems.identifier, "not the owned native toolbar")
        precondition(toolbar.items.map(\.itemIdentifier) == MemoWeaverToolbarItems.defaultOrder,
                     "toolbar must have list, flexible spacer, focus, new, right, search")
        precondition(toolbar.items.contains(where: { $0.itemIdentifier == .flexibleSpace }),
                     "flexible spacer is essential for the Finder-style trailing group")
        guard let tabItem = toolbar.items.first(where: { $0.itemIdentifier == MemoWeaverToolbarItems.paneTabs }),
              let tabControl = tabItem.view as? NSSegmentedControl else { fatalError("Missing native view segments") }
        precondition(tabControl.selectedSegment == 0, "preview should be selected")
        guard let right = toolbar.items.first(where: { $0.itemIdentifier == MemoWeaverToolbarItems.right }),
              let list = toolbar.items.first(where: { $0.itemIdentifier == MemoWeaverToolbarItems.list }),
              let search = toolbar.items.first(where: { $0.itemIdentifier == MemoWeaverToolbarItems.search })
                as? NSSearchToolbarItem else { fatalError("Required toolbar controls missing") }
        precondition(right.isEnabled, "right-pane button must work with a selected note")
        precondition(right.toolTip?.contains("닫기") == true, "right pane initially open")
        precondition(window.toolbarStyle == .unifiedCompact, "compact unified native toolbar")
        precondition(window.styleMask.contains(.fullSizeContentView), "full-height sidebar")
        precondition(window.titleVisibility == .hidden, "redundant page title")
        precondition(window.titlebarAppearsTransparent, "transparent titlebar")

        var selectedTab: String?
        var rightClicks = 0
        var listClicks = 0
        var newClicks = 0
        var receivedSearch: String?
        let center = NotificationCenter.default
        let tokens: [NSObjectProtocol] = [
            center.addObserver(forName: .memoWeaverToggleRightPane, object: nil, queue: nil) { _ in rightClicks += 1 },
            center.addObserver(forName: .memoWeaverToggleNoteList, object: nil, queue: nil) { _ in listClicks += 1 },
            center.addObserver(forName: .memoWeaverCreateNewNote, object: nil, queue: nil) { _ in newClicks += 1 },
            center.addObserver(forName: .memoWeaverSelectRightPaneTab, object: nil, queue: nil) {
                selectedTab = $0.userInfo?["tab"] as? String
            },
            center.addObserver(forName: .memoWeaverOpenQuickSearch, object: nil, queue: nil) {
                receivedSearch = $0.userInfo?["query"] as? String
            }
        ]
        if let action = right.action { _ = NSApp.sendAction(action, to: right.target, from: right) }
        if let action = list.action { _ = NSApp.sendAction(action, to: list.target, from: list) }
        if let item = toolbar.items.first(where: { $0.itemIdentifier == MemoWeaverToolbarItems.newNote }),
           let action = item.action {
            _ = NSApp.sendAction(action, to: item.target, from: item)
        }
        precondition(rightClicks == 1 && listClicks == 1 && newClicks == 1,
                     "native button actions must reach the app via notifications")
        search.searchField.stringValue = "회의록"
        if let action = search.searchField.action {
            _ = NSApp.sendAction(action, to: search.searchField.target, from: search.searchField)
        }
        precondition(receivedSearch == "회의록", "native toolbar search must pass text to quick search")
        tabControl.selectedSegment = 1
        if let action = tabControl.action {
            _ = NSApp.sendAction(action, to: tabControl.target, from: tabControl)
        }
        precondition(selectedTab == "memory", "native view switcher must preserve tab navigation")

        let noSelection = MemoWeaverToolbarSnapshot(listVisible: false, rightVisible: false,
                                                    focusMode: false, isNotePage: true,
                                                    hasCurrentNote: false, rightTab: "memory")
        host.rootView = MemoWeaverNativeWindowChrome(snapshot: noSelection)
            .frame(width: 1, height: 1)
        window.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        precondition(window.toolbar === toolbar, "toolbar must not be recreated on state updates")
        precondition(!right.isEnabled, "right button must remain visible but disabled without a note")
        precondition(!tabControl.isEnabled, "native view tabs disabled without a note")
        precondition(toolbar.items.contains(where: { $0.itemIdentifier == MemoWeaverToolbarItems.right }),
                     "right button must never vanish when no note is selected")

        let reopened = MemoWeaverToolbarSnapshot(listVisible: true, rightVisible: false,
                                                  focusMode: false, isNotePage: true,
                                                  hasCurrentNote: true, rightTab: "reference")
        host.rootView = MemoWeaverNativeWindowChrome(snapshot: reopened).frame(width: 1, height: 1)
        window.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        precondition(right.isEnabled, "right action must reactivate when a note is selected")
        precondition(tabControl.selectedSegment == 2, "previously selected pane tab must restore")
        precondition(right.toolTip?.contains("열기") == true, "right pane button must show open state")

        // Minimum supported window width: the right-pane command stays
        // visible before the lower-priority search field is collapsed.
        window.setContentSize(NSSize(width: 970, height: 650))
        window.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        precondition(right.isVisible, "right-pane toggle must remain visible at 970pt")
        precondition(list.isVisible, "note-list toggle must remain visible at 970pt")

        for token in tokens { center.removeObserver(token) }
        window.orderOut(nil)
        window.close()
        print("PASS v0.9.38 real AppKit toolbar: flexible spacer, both toggles, search, state, full-height window")
    }
}
