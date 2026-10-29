import AppKit
import Foundation

@main struct NativeWindowMinimumV0949Smoke {
    static func main() {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 1300, height: 840),
            styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        for (list, right) in [(true, true), (false, true), (true, false), (false, false)] {
            let width = MemoWeaverToolbarGeometry.minimumContentWidth(
                isNotePage: true, listVisible: list, rightVisible: right,
                focusMode: false, preferredListWidth: 245, preferredRightWidth: 340,
                dividerThickness: 1)
            window.contentMinSize = NSSize(width: width, height: 640)
            precondition(abs(window.contentMinSize.width-width) < 1)
            precondition(abs(window.contentMinSize.height-640) < 1)
        }
        // Check the AppKit frame API with the same pure expansion rule used
        // by the workspace when reopening a pane. No user preferences touched.
        let current = window.frame
        let next = MemoWeaverToolbarGeometry.expansionFrame(
            current: current,
            requiredFrameWidth: current.width + 90,
            visibleFrame: NSRect(x: 0, y: 0, width: 3000, height: 1900))
        window.setFrame(next, display: false, animate: false)
        precondition(window.frame.width >= current.width + 89)
        print("PASS native macOS v0.9.49: contentMinSize and explicit setFrame growth")
        window.close()
    }
}
