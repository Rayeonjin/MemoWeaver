import AppKit
import SwiftUI

// Only VISIBLE panes are actual NSSplitView arranged subviews. In v0.9.27-28,
// hidden NSHostingViews remained arranged split panes, so AppKit continued to
// draw divider artifacts and divider indices no longer matched actual panes.
// Keep a single persistent hosting view for each pane (the editor is NEVER
// removed), but remove closed side panes from the NSView hierarchy entirely.
// Native NSSplitView tracks dividers; only mouse-up persists outer widths.
struct MemoWeaverPinnedSplitView<ListPane: View, EditorPane: View, RightPane: View>: NSViewRepresentable {
    let list: ListPane
    let editor: EditorPane
    let right: RightPane
    let listVisible: Bool
    let rightVisible: Bool
    let listPreferred: CGFloat
    let rightPreferred: CGFloat
    let saveListWidth: (CGFloat) -> Void
    let saveRightWidth: (CGFloat) -> Void
    let onRatioMeasured: (Int) -> Void
    let ratioRequest: MemoWeaverPaneRatioRequest?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSSplitView {
        let split = NSSplitView(frame: .zero)
        // AppKit titlebar tracking identifies this exact native split by ID.
        split.identifier = NSUserInterfaceItemIdentifier("MemoWeaver.notes.pinnedSplit")
        split.isVertical = true
        split.dividerStyle = .thin
        split.arrangesAllSubviews = false
        let left = NSHostingView(rootView: list)
        let center = NSHostingView(rootView: editor)
        let auxiliary = NSHostingView(rootView: right)
        for view in [left as NSView, center as NSView, auxiliary as NSView] {
            // Pane bounds, not the hosted SwiftUI view's intrinsic content
            // size, own the frame. Prevent content bleeding over a divider.
            view.wantsLayer = true
            view.layer?.masksToBounds = true
        }
        left.sizingOptions = []
        center.sizingOptions = []
        auxiliary.sizingOptions = []
        let state = context.coordinator
        state.listHost = left
        state.editorHost = center
        state.rightHost = auxiliary
        state.listVisible = listVisible
        state.rightVisible = rightVisible
        state.listPreferred = listPreferred
        state.rightPreferred = rightPreferred
        state.lastExternalListWidth = listPreferred
        state.lastExternalRightWidth = rightPreferred
        state.saveListWidth = saveListWidth
        state.saveRightWidth = saveRightWidth
        state.onRatioMeasured = onRatioMeasured
        // The first update may be the first opportunity to apply the ratio
        // after NSSplitView obtains its actual nonzero bounds.
        state.lastRatioRequestID = nil
        split.delegate = state
        state.reconcileArrangedPanes(in: split)
        state.applyPreferredFrames(in: split)
        return split
    }

    func updateNSView(_ split: NSSplitView, context: Context) {
        let state = context.coordinator
        state.listHost?.rootView = list
        state.editorHost?.rootView = editor
        state.rightHost?.rootView = right
        state.saveListWidth = saveListWidth
        state.saveRightWidth = saveRightWidth
        state.onRatioMeasured = onRatioMeasured
        let visibilityChanged = listVisible != state.listVisible || rightVisible != state.rightVisible
        // Compare incoming AppStorage with the LAST value supplied by the
        // parent, not the coordinator's live width. A mouse-up save is async;
        // unrelated SwiftUI updates may still contain its older value.
        let externalListChanged = abs(listPreferred - state.lastExternalListWidth) > 0.5
        let externalRightChanged = abs(rightPreferred - state.lastExternalRightWidth) > 0.5
        let captured = visibilityChanged
            ? state.captureVisibleWidthsBeforeTransition(in: split) : (list: nil, right: nil)
        if visibilityChanged { state.cancelPendingDragAfterCapturing() }
        state.listVisible = listVisible
        state.rightVisible = rightVisible
        state.listPreferred = captured.list ?? (externalListChanged ? listPreferred : state.listPreferred)
        state.rightPreferred = captured.right ?? (externalRightChanged ? rightPreferred : state.rightPreferred)
        state.lastExternalListWidth = listPreferred
        state.lastExternalRightWidth = rightPreferred
        if visibilityChanged || ((externalListChanged || externalRightChanged) && !state.savingUserDrag) {
            state.suppressDragObservation = true
            if visibilityChanged {
                // Remove closed panes from the actual NSSplitView hierarchy.
                state.reconcileArrangedPanes(in: split)
            }
            state.applyPreferredFrames(in: split)
            split.needsLayout = true
            split.needsDisplay = true
            state.suppressDragObservation = false
        }
        // Never mutate AppStorage synchronously from updateNSView.
        if let width = captured.list {
            let save = state.saveListWidth
            DispatchQueue.main.async { save?(width) }
        }
        if let width = captured.right {
            let save = state.saveRightWidth
            DispatchQueue.main.async { save?(width) }
        }
        // One-shot button request: move the actual native divider, then
        // persist only the resulting auxiliary width. No pane remount.
        if let request = ratioRequest, state.lastRatioRequestID != request.id,
           let width = state.applyRatioPreset(request.preset, in: split) {
            // Mark applied only on success: if a request arrives while AppKit
            // is resizing or the split has zero width, retry on next update.
            state.lastRatioRequestID = request.id
            let save = state.saveRightWidth
            DispatchQueue.main.async { save?(width) }
        }
    }

    final class Coordinator: NSObject, NSSplitViewDelegate {
        var listHost: NSHostingView<ListPane>?
        var editorHost: NSHostingView<EditorPane>?
        var rightHost: NSHostingView<RightPane>?
        var listVisible = true
        var rightVisible = false
        var listPreferred: CGFloat = 0
        var rightPreferred: CGFloat = 0
        var lastExternalListWidth: CGFloat = 0
        var lastExternalRightWidth: CGFloat = 0
        var saveListWidth: ((CGFloat) -> Void)?
        var saveRightWidth: ((CGFloat) -> Void)?
        var onRatioMeasured: ((Int) -> Void)?
        private var lastMeasuredRatioPercent: Int?
        var savingUserDrag = false
        var suppressDragObservation = false
        var lastRatioRequestID: UUID?
        private enum DragTarget { case list, right }
        private var trackedDivider: DragTarget?
        private var pendingDragEnd: DispatchWorkItem?

        // Invariant: arrangedSubviews is exactly [list? , editor, right?],
        // matching the visible columns AND the dividers AppKit draws.
        // Removed hosts are retained by the coordinator for reopening, so
        // the central editor is never recreated or detached during toggles.
        func reconcileArrangedPanes(in split: NSSplitView) {
            guard let left = listHost, let center = editorHost, let auxiliary = rightHost else { return }
            let expected: [NSView] = MemoWeaverPinnedPaneLayout.visiblePaneOrder(
                listVisible: listVisible, rightVisible: rightVisible).map { pane in
                switch pane {
                case .list: return left
                case .editor: return center
                case .right: return auxiliary
                }
            }
            for pane in split.arrangedSubviews where !expected.contains(where: { $0 === pane }) {
                // Unlike removeArrangedSubview(), removeFromSuperview() also
                // removes the physical subview when arrangesAllSubviews=false.
                pane.removeFromSuperview()
            }
            for (index, pane) in expected.enumerated() {
                if index < split.arrangedSubviews.count, split.arrangedSubviews[index] === pane {
                    continue
                }
                if pane.superview != nil { pane.removeFromSuperview() }
                split.insertArrangedSubview(pane, at: index)
            }
        }


        // At a pane visibility transition, snapshot BOTH currently visible
        // side widths, not just the pane being closed. This handles:
        // right closed -> drag list -> reopen right, even before the 180ms
        // mouse-up persistence timer has run. Never save window compression.
        func captureVisibleWidthsBeforeTransition(in split: NSSplitView)
            -> (list: CGFloat?, right: CGFloat?) {
            guard !split.inLiveResize else { return (nil, nil) }
            let common = (split.bounds.width, split.dividerThickness)
            let list = listHost.flatMap { host -> CGFloat? in
                guard host.superview === split else { return nil }
                return MemoWeaverPinnedPaneLayout.userWidthBeforeVisibilityChange(
                    pane: .list, observed: host.frame.width,
                    totalWidth: common.0, dividerThickness: common.1,
                    listVisible: listVisible, rightVisible: rightVisible,
                    savedListWidth: listPreferred, savedRightWidth: rightPreferred)
            }
            let right = rightHost.flatMap { host -> CGFloat? in
                guard host.superview === split else { return nil }
                return MemoWeaverPinnedPaneLayout.userWidthBeforeVisibilityChange(
                    pane: .right, observed: host.frame.width,
                    totalWidth: common.0, dividerThickness: common.1,
                    listVisible: listVisible, rightVisible: rightVisible,
                    savedListWidth: listPreferred, savedRightWidth: rightPreferred)
            }
            return (list, right)
        }

        // Preserve compatibility with the v0.9.29 macOS smoke test. The real
        // transition path above captures both visible panes before remapping.
        func captureWidthsBeforeClosing(in split: NSSplitView,
                                        closingList: Bool, closingRight: Bool)
            -> (list: CGFloat?, right: CGFloat?) {
            let captured = captureVisibleWidthsBeforeTransition(in: split)
            return (closingList ? captured.list : nil, closingRight ? captured.right : nil)
        }

        func cancelPendingDragAfterCapturing() {
            pendingDragEnd?.cancel()
            pendingDragEnd = nil
            trackedDivider = nil
            savingUserDrag = false
        }

        // Called when the actual window resizes. The two saved outer widths
        // take priority; the editor receives the extra (or missing) space.
        func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
            applyPreferredFrames(in: splitView)
        }

        func applyPreferredFrames(in splitView: NSSplitView) {
            guard let left = listHost, let center = editorHost, let auxiliary = rightHost else { return }
            let sizes = MemoWeaverPinnedPaneLayout.resolved(
                totalWidth: splitView.bounds.width,
                dividerThickness: splitView.dividerThickness,
                listVisible: listVisible, rightVisible: rightVisible,
                savedListWidth: listPreferred, savedRightWidth: rightPreferred)
            let height = max(0, splitView.bounds.height)
            let activeDividerCount = max(0, splitView.arrangedSubviews.count - 1)
            let divider = activeDividerCount > 0 ? sizes.divider / CGFloat(activeDividerCount) : 0
            let leftWidth = listVisible ? sizes.list : 0
            let centerX = listVisible ? leftWidth + divider : 0
            let rightX = centerX + sizes.editor + (rightVisible ? divider : 0)
            left.frame = NSRect(x: 0, y: 0, width: leftWidth, height: height)
            center.frame = NSRect(x: centerX, y: 0, width: sizes.editor, height: height)
            auxiliary.frame = NSRect(x: rightX, y: 0,
                                     width: rightVisible ? sizes.right : 0, height: height)
            reportMeasuredRatio(in: splitView)
        }

        private func reportMeasuredRatio(in split: NSSplitView) {
            guard rightVisible, !savingUserDrag,
                  NSEvent.pressedMouseButtons == 0,
                  let editor = editorHost, let right = rightHost,
                  editor.superview === split, right.superview === split,
                  let percent = MemoWeaverPinnedPaneLayout.editorPercent(
                    editorWidth: editor.frame.width, rightWidth: right.frame.width),
                  percent != lastMeasuredRatioPercent else { return }
            lastMeasuredRatioPercent = percent
            let callback = onRatioMeasured
            // A native layout/delegate callback must not mutate SwiftUI State
            // during updateNSView or the current split layout pass.
            DispatchQueue.main.async { callback?(percent) }
        }

        func applyRatioPreset(_ preset: MemoWeaverPaneRatioPreset,
                              in split: NSSplitView) -> CGFloat? {
            guard rightVisible, !split.inLiveResize, !savingUserDrag,
                  let left = listHost, let auxiliary = rightHost,
                  auxiliary.superview === split else { return nil }
            // Calculate from actual NSSplitView bounds, not the window width:
            // sidebar visibility and persisted list width affect available room.
            let dividerCount = max(0, split.arrangedSubviews.count - 1)
            let remaining = split.bounds.width - CGFloat(dividerCount) * split.dividerThickness
                - (listVisible ? left.frame.width : 0)
            guard let target = MemoWeaverPinnedPaneLayout.rightWidth(
                for: preset, combinedWidth: remaining) else { return nil }
            suppressDragObservation = true
            rightPreferred = target
            applyPreferredFrames(in: split)
            split.needsLayout = true
            split.needsDisplay = true
            suppressDragObservation = false
            reportMeasuredRatio(in: split)
            return target
        }

        func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
            false // Closing a pane is only through the explicit UI control.
        }

        func splitView(_ splitView: NSSplitView, constrainSplitPosition proposedPosition: CGFloat,
                       ofSubviewAt dividerIndex: Int) -> CGFloat {
            guard let left = listHost, let center = editorHost, let auxiliary = rightHost else {
                return proposedPosition
            }
            // Divider indices always refer to the actual ARRANGED pane order.
            // When the list is closed, index 0 is editor/right, not list/editor.
            let panes = splitView.arrangedSubviews
            guard dividerIndex >= 0, dividerIndex < panes.count - 1 else {
                return proposedPosition
            }
            let preceding = panes[dividerIndex]
            let width = splitView.bounds.width
            let d = splitView.dividerThickness
            if preceding === left {
                if !suppressDragObservation && NSEvent.pressedMouseButtons & 1 != 0 {
                    trackedDivider = .list
                }
                let rightSpace = rightVisible ? auxiliary.frame.width + d : 0
                let low = MemoWeaverPinnedPaneLayout.listMinimum
                let high = width - rightSpace - MemoWeaverPinnedPaneLayout.editorMinimum - d
                return max(0, min(max(low, high), max(low, proposedPosition)))
            }
            if preceding === center && rightVisible {
                if !suppressDragObservation && NSEvent.pressedMouseButtons & 1 != 0 {
                    trackedDivider = .right
                }
                let low = (listVisible ? left.frame.width + d : 0) + MemoWeaverPinnedPaneLayout.editorMinimum
                let high = width - MemoWeaverPinnedPaneLayout.rightMinimum - d
                return max(0, min(max(low, high), max(low, proposedPosition)))
            }
            return proposedPosition
        }

        func splitViewDidResizeSubviews(_ notification: Notification) {
            // Never save the temporarily compressed width during a WINDOW
            // resize or a programmatic panel show/hide transition.
            guard !suppressDragObservation,
                  trackedDivider != nil,
                  let split = notification.object as? NSSplitView,
                  !split.inLiveResize else { return }
            savingUserDrag = true
            scheduleDragEnd()
        }

        private func scheduleDragEnd() {
            guard pendingDragEnd == nil else { return }
            let item = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.pendingDragEnd = nil
                if NSEvent.pressedMouseButtons & 1 != 0 {
                    self.scheduleDragEnd()
                    return
                }
                let completedDivider = self.trackedDivider
                self.trackedDivider = nil
                self.savingUserDrag = false
                // Update the footer from the final released divider position;
                // never invalidate SwiftUI on each mouse-move during drag.
                if let split = self.editorHost?.superview as? NSSplitView {
                    self.reportMeasuredRatio(in: split)
                }
                // Check active arranged panes before saving: a panel may have
                // closed between mouse-up and this deferred persistence.
                if completedDivider == .list, self.listVisible,
                   let list = self.listHost, list.superview != nil,
                   let width = self.listHost?.frame.width, width > 1,
                   abs(width - self.resolvedPreference(self.listPreferred,
                       fallback: MemoWeaverPinnedPaneLayout.listDefault)) > 0.5 {
                    self.listPreferred = width
                    self.saveListWidth?(width)
                }
                if completedDivider == .right, self.rightVisible,
                   let right = self.rightHost, right.superview != nil,
                   let width = self.rightHost?.frame.width, width > 1,
                   abs(width - self.resolvedPreference(self.rightPreferred,
                       fallback: MemoWeaverPinnedPaneLayout.rightDefault)) > 0.5 {
                    self.rightPreferred = width
                    self.saveRightWidth?(width)
                }
            }
            pendingDragEnd = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: item)
        }

        private func resolvedPreference(_ width: CGFloat, fallback: CGFloat) -> CGFloat {
            width > 0 && width.isFinite ? width : fallback
        }

        deinit { pendingDragEnd?.cancel() }
    }
}
