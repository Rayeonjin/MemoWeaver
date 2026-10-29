import AppKit
import SwiftUI
import Foundation

@main struct PinnedPaneAppKitV0932Smoke {
    static func require(_ ok: @autoclosure () -> Bool, _ message: String) {
        if !ok() { fputs("FAIL AppKit v0.9.32: \(message)\n", stderr); exit(1) }
    }
    static func main() {
        _ = NSApplication.shared
        let coordinator = MemoWeaverPinnedSplitView<Text, Text, Text>.Coordinator()
        let split = NSSplitView(frame: NSRect(x: 0, y: 0, width: 1400, height: 600))
        split.isVertical = true; split.dividerStyle = .thin
        split.arrangesAllSubviews = false
        let list = NSHostingView(rootView: Text("list"))
        let editor = NSHostingView(rootView: Text("editor"))
        let right = NSHostingView(rootView: Text("right"))
        coordinator.listHost = list
        coordinator.editorHost = editor
        coordinator.rightHost = right
        coordinator.listPreferred = 245
        coordinator.rightPreferred = 390
        coordinator.listVisible = true
        coordinator.rightVisible = false
        split.delegate = coordinator
        for _ in 0..<60 {
            // Start in a two-column workspace.
            coordinator.rightVisible = false
            coordinator.reconcileArrangedPanes(in: split)
            coordinator.applyPreferredFrames(in: split)
            require(split.arrangedSubviews.count == 2, "closed right panel left divider")
            // Simulate a real list drag before its 180ms mouse-up save.
            let chosen: CGFloat = 324
            list.frame = NSRect(x: 0, y: 0, width: chosen, height: 600)
            editor.frame = NSRect(x: chosen + split.dividerThickness, y: 0,
                width: 1400 - chosen - split.dividerThickness, height: 600)
            let capture = coordinator.captureVisibleWidthsBeforeTransition(in: split)
            require(abs((capture.list ?? -1) - chosen) < 0.1,
                    "did not capture a list resize before opening auxiliary pane")
            coordinator.listPreferred = capture.list!
            coordinator.cancelPendingDragAfterCapturing()
            coordinator.rightVisible = true
            coordinator.reconcileArrangedPanes(in: split)
            coordinator.applyPreferredFrames(in: split)
            require(abs(list.frame.width - chosen) < 0.1,
                    "opening right pane changed list width")
            require(abs(right.frame.width - 390) < 0.1,
                    "right pane did not recover its width")
            require(editor.frame.width > 240, "editor violated minimum")
            require(split.arrangedSubviews.count == 3, "right pane not arranged")
        }
        print("PASS v0.9.32 macOS AppKit: right reopen after resized list, 60 cycles")
    }
}
