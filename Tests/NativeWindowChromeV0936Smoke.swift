import AppKit
import SwiftUI

// macOS-only, synthetic window. No user data or installed application is used.
@main
struct NativeWindowChromeV0936Smoke {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let window = NSWindow(contentRect: NSRect(x: 80, y: 80, width: 900, height: 600),
                              styleMask: [.titled, .resizable, .closable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.contentView = NSHostingView(rootView: MemoWeaverNativeWindowChrome()
            .frame(width: 1, height: 1))
        window.makeKeyAndOrderFront(nil)
        window.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        precondition(window.toolbarStyle == .unifiedCompact,
                     "native unified compact toolbar style not installed")
        precondition(window.styleMask.contains(.fullSizeContentView),
                     "full-height content not installed")
        precondition(window.titleVisibility == .hidden, "duplicate native title visible")
        precondition(window.titlebarAppearsTransparent, "sidebar cannot extend under titlebar")
        precondition(window.titlebarSeparatorStyle == .none, "duplicate titlebar separator")
        precondition(window.toolbar != nil, "native toolbar was not created")
        window.orderOut(nil)
        window.close()
        print("PASS macOS native unified titlebar + full-size content (synthetic window)")
    }
}
