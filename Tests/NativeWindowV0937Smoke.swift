import AppKit
import SwiftUI

// A native AppKit smoke test independent of user notes and real windows.
// SwiftUI owns production ToolbarItems. A populated synthetic NSToolbar here
// confirms the titlebar anchor never replaces or deletes a populated toolbar.
private final class QAItemProvider: NSObject, NSToolbarDelegate {
    let actionID = NSToolbarItem.Identifier("MemoWeaver.QA.NativeToolbarAction")
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [actionID, .flexibleSpace]
    }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [actionID]
    }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard identifier == actionID else { return nil }
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = "메모 목록"
        item.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: "메모 목록")
        return item
    }
}

@main
struct NativeWindowV0937Smoke {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let window = NSWindow(contentRect: NSRect(x: 90, y: 90, width: 1060, height: 650),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        let provider = QAItemProvider()
        let toolbar = NSToolbar(identifier: "MemoWeaver.QA.NativeToolbar")
        toolbar.delegate = provider
        window.toolbar = toolbar
        window.contentView = NSHostingView(rootView:
            MemoWeaverNativeWindowChrome().frame(width: 1, height: 1))
        window.makeKeyAndOrderFront(nil)
        window.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        precondition(window.toolbar === toolbar, "chrome must not override a populated toolbar")
        precondition(toolbar.items.contains(where: { $0.itemIdentifier == provider.actionID }),
                     "synthetic native toolbar must have a real action")
        precondition(window.toolbarStyle == .unifiedCompact, "toolbar style")
        precondition(window.styleMask.contains(.fullSizeContentView), "full height content")
        precondition(window.titleVisibility == .hidden, "redundant title")
        precondition(window.titlebarAppearsTransparent, "opaque titlebar")
        precondition(window.titlebarSeparatorStyle == .none, "redundant separator")
        window.orderOut(nil)
        window.close()
        print("PASS native titlebar preserves populated toolbar, full-size content and transparent sidebar")
    }
}
