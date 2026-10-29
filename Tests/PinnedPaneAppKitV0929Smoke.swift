import AppKit
import SwiftUI
import Foundation

@main struct PinnedPaneAppKitV0929Smoke {
    static func require(_ ok: @autoclosure () -> Bool, _ message: String) {
        if !ok() { fputs("FAIL AppKit v0.9.29: \(message)\n", stderr); exit(1) }
    }
    static func main() {
        _ = NSApplication.shared
        typealias Model = MemoWeaverPinnedPaneLayout
        typealias PaneView = MemoWeaverPinnedSplitView<Text, Text, Text>
        let coordinator = PaneView.Coordinator()
        let split = NSSplitView(frame: NSRect(x: 0, y: 0, width: 1400, height: 700))
        split.isVertical = true
        split.dividerStyle = .thin
        split.arrangesAllSubviews = false
        let list = NSHostingView(rootView: Text("list"))
        let editor = NSHostingView(rootView: Text("editor"))
        let right = NSHostingView(rootView: Text("right"))
        for view in [list as NSView, editor as NSView, right as NSView] {
            view.wantsLayer = true
            view.layer?.masksToBounds = true
        }
        coordinator.listHost = list
        coordinator.editorHost = editor
        coordinator.rightHost = right
        coordinator.listPreferred = 300
        coordinator.rightPreferred = 390
        split.delegate = coordinator
        let scenarios: [(Bool, Bool)] = [
            (true, true), (true, false), (true, true),
            (false, true), (true, true), (false, false),
            (true, true), (false, true), (false, false),
            (true, false), (true, true)
        ]
        for _ in 0..<40 {
            for (listVisible, rightVisible) in scenarios {
                coordinator.listVisible = listVisible
                coordinator.rightVisible = rightVisible
                coordinator.reconcileArrangedPanes(in: split)
                coordinator.applyPreferredFrames(in: split)
                let expectedOrder = Model.visiblePaneOrder(
                    listVisible: listVisible, rightVisible: rightVisible)
                require(split.arrangedSubviews.count == expectedOrder.count,
                        "a hidden panel is still arranged")
                require(split.subviews.count == expectedOrder.count,
                        "a hidden panel left a physical subview")
                for (index, kind) in expectedOrder.enumerated() {
                    let pane = split.arrangedSubviews[index]
                    switch kind {
                    case .list: require(pane === list, "wrong list position")
                    case .editor: require(pane === editor, "editor recreated/detached")
                    case .right: require(pane === right, "wrong right position")
                    }
                }
                require(editor.superview === split, "editor detached during toggle")
                require((list.superview === split) == listVisible, "list incorrectly attached")
                require((right.superview === split) == rightVisible, "right incorrectly attached")
                if listVisible {
                    require(abs(list.frame.width - 300) < 1, "chosen list width lost")
                }
                if rightVisible {
                    require(abs(right.frame.width - 390) < 1, "chosen right width lost")
                }
                let expectedDividers = (listVisible ? 1 : 0) + (rightVisible ? 1 : 0)
                require(split.arrangedSubviews.count - 1 == expectedDividers,
                        "ghost divider remains after closing")
            }
        }
        // Simulate a right-pane user drag not yet written by its mouse-up
        // persistence timer. Closing must capture 430pt instead of reopening
        // at the older 390pt preference.
        coordinator.listVisible = true
        coordinator.rightVisible = true
        coordinator.reconcileArrangedPanes(in: split)
        coordinator.applyPreferredFrames(in: split)
        let movedWidth: CGFloat = 430
        let movedStart = right.frame.minX - (movedWidth - right.frame.width)
        right.frame = NSRect(x: movedStart, y: 0, width: movedWidth, height: 700)
        let pending = coordinator.captureWidthsBeforeClosing(
            in: split, closingList: false, closingRight: true)
        require(abs((pending.right ?? 0) - movedWidth) < 0.01,
                "right width lost between dragging and closing")
        // In a genuinely narrow window, temporary compression must never
        // overwrite the saved wider user preference.
        split.frame = NSRect(x: 0, y: 0, width: 740, height: 700)
        coordinator.applyPreferredFrames(in: split)
        let temporary = coordinator.captureWidthsBeforeClosing(
            in: split, closingList: false, closingRight: true)
        require(temporary.right == nil, "temporary width was persisted")
        print("PASS v0.9.29 macOS AppKit: 440 pane transitions + closing-width preservation")
    }
}
