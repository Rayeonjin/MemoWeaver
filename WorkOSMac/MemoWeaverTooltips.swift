import AppKit
import SwiftUI

// v0.9.53: A tooltip is a non-interactive hint, never a modal/transient
// NSPopover. An NSPopover swallowed the first click on its trigger. A passive
// window ignores mouse events, and the click goes to the button immediately.
private struct MemoWeaverTooltipModifier: ViewModifier {
    @AppStorage("memoweaver.ui.tooltipsEnabled") private var tooltipsEnabled = true
    @State private var isHovering = false
    @State private var anchorBox = MemoWeaverPassiveTooltipAnchorBox()
    let message: String

    func body(content: Content) -> some View {
        content
            .background(MemoWeaverPassiveTooltipAnchor(box: anchorBox))
            .onHover { hovering in
                isHovering = hovering
                if hovering, tooltipsEnabled, let view = anchorBox.view {
                    MemoWeaverPassiveTooltipCenter.shared.schedule(
                        message: message, anchor: view, owner: anchorBox)
                } else {
                    MemoWeaverPassiveTooltipCenter.shared.hide(for: anchorBox)
                }
            }
            .onDisappear {
                MemoWeaverPassiveTooltipCenter.shared.hide(for: anchorBox)
            }
            .onChange(of: tooltipsEnabled) { _, enabled in
                if !enabled {
                    MemoWeaverPassiveTooltipCenter.shared.hide(for: anchorBox)
                } else if isHovering, let view = anchorBox.view {
                    MemoWeaverPassiveTooltipCenter.shared.schedule(
                        message: message, anchor: view, owner: anchorBox)
                }
            }
            .onChange(of: message) { _, updated in
                if isHovering, tooltipsEnabled, let view = anchorBox.view {
                    MemoWeaverPassiveTooltipCenter.shared.schedule(
                        message: updated, anchor: view, owner: anchorBox)
                }
            }
    }
}

extension View {
    func memoTooltip(_ message: String) -> some View {
        modifier(MemoWeaverTooltipModifier(message: message))
    }

    // Keep the view free of hover trackers unless the label is icon-only,
    // truncated, or disambiguates multiple notebooks. Accessibility labels
    // remain available independently of the visual tooltip setting.
    @ViewBuilder func memoTooltip(_ message: String, when condition: Bool) -> some View {
        if condition { memoTooltip(message) }
        else { self }
    }
}
