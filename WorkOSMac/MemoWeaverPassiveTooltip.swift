import AppKit
import SwiftUI

// A passive hint is NOT an NSPopover. In particular, it cannot become the
// mouse-event target, dismiss in response to mouseDown, or consume a button's
// first click. Both SwiftUI controls and native toolbar buttons use this one
// presenter, with the same short delay and accessibility-independent opt-out.
private final class MemoWeaverPassiveTooltipPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// Draw text directly rather than using NSTextField's undocumented cell insets.
// One measurement, one frame: the left/right padding is exactly 10pt.
private final class MemoWeaverTooltipContentView: NSView {
    let message: NSAttributedString
    let horizontalPadding: CGFloat = 10
    let verticalPadding: CGFloat = 7

    init(message: String) {
        let font = NSFont.systemFont(ofSize: 12, weight: .regular)
        self.message = NSAttributedString(string: message, attributes: [
            .font: font, .foregroundColor: NSColor.white
        ])
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.backgroundColor = NSColor(calibratedWhite: 0.17, alpha: 0.97).cgColor
        layer?.borderColor = NSColor(calibratedWhite: 0.42, alpha: 0.75).cgColor
        layer?.borderWidth = 0.5
    }
    required init?(coder: NSCoder) { return nil }

    static func measuredSize(for message: String) -> NSSize {
        let font = NSFont.systemFont(ofSize: 12, weight: .regular)
        let attr = NSAttributedString(string: message, attributes: [.font: font])
        let paddingX: CGFloat = 10
        let paddingY: CGFloat = 7
        // NSString/NSAttributedString and the native text field measured
        // different effective insets in v0.9.60. The custom drawing view
        // uses precisely the same attributed string as this calculation.
        let oneLine = ceil(attr.size().width) + 3
        let contentWidth = min(310, max(48, oneLine))
        let rect = attr.boundingRect(
            with: NSSize(width: contentWidth, height: 1200),
            options: [.usesLineFragmentOrigin, .usesFontLeading])
        let textHeight = max(ceil(font.ascender - font.descender + font.leading), ceil(rect.height))
        return NSSize(width: contentWidth + 2 * paddingX,
                      height: textHeight + 2 * paddingY)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let rect = bounds.insetBy(dx: horizontalPadding, dy: verticalPadding)
        message.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
    }
}

final class MemoWeaverPassiveTooltipCenter {
    static let shared = MemoWeaverPassiveTooltipCenter()
    static let hoverDelay: TimeInterval = 0.13

    private weak var owner: AnyObject?
    private weak var parentWindow: NSWindow?
    private var pending: DispatchWorkItem?
    private var panel: NSPanel?
    private var clickMonitor: Any?
    private var resignObserver: NSObjectProtocol?

    private init() {}

    func schedule(message: String, anchor: NSView, owner newOwner: AnyObject) {
        dismiss()
        guard !message.isEmpty, anchor.window != nil else { return }
        owner = newOwner
        let work = DispatchWorkItem { [weak self, weak anchor, weak newOwner] in
            guard let self, let anchor, let newOwner,
                  self.owner === newOwner else { return }
            self.present(message: message, anchor: anchor)
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.hoverDelay, execute: work)
    }

    func hide(for requester: AnyObject) {
        guard owner === requester else { return }
        dismiss()
    }

    // Clicking is never blocked: the passive panel ignores ALL mouse events,
    // and this monitor returns the ORIGINAL event unchanged to the target.
    private func installClickDismissMonitor() {
        clickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            self?.dismiss()
            return event
        }
    }

    private func dismiss() {
        pending?.cancel()
        pending = nil
        owner = nil
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
            self.resignObserver = nil
        }
        if let panel {
            panel.orderOut(nil)
            parentWindow?.removeChildWindow(panel)
            self.panel = nil
        }
        parentWindow = nil
    }

    private func present(message: String, anchor: NSView) {
        guard let parent = anchor.window, !anchor.isHidden else { return }
        let panelSize = MemoWeaverTooltipContentView.measuredSize(for: message)
        let anchorInWindow = anchor.convert(anchor.bounds, to: nil)
        let anchorInScreen = parent.convertToScreen(anchorInWindow)
        let screen = parent.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let padding: CGFloat = 6
        let x = max(screen.minX + padding,
                    min(anchorInScreen.midX - panelSize.width / 2,
                        screen.maxX - panelSize.width - padding))
        var y = anchorInScreen.minY - panelSize.height - 6
        if y < screen.minY + padding {
            y = anchorInScreen.maxY + 6
        }
        y = max(screen.minY + padding,
                min(y, screen.maxY - panelSize.height - padding))
        let panel = MemoWeaverPassiveTooltipPanel(
            contentRect: NSRect(origin: NSPoint(x: x, y: y), size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.transient, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = true

        let background = MemoWeaverTooltipContentView(message: message)
        background.frame = NSRect(origin: .zero, size: panelSize)
        panel.contentView = background
        parentWindow = parent
        parent.addChildWindow(panel, ordered: .above)
        panel.orderFront(nil)
        self.panel = panel
        installClickDismissMonitor()
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.dismiss()
        }
    }
}

// This view is just a geometry anchor. It is behind the SwiftUI control and
// cannot become a hit-test target, so menus, buttons and popovers receive the
// first click exactly as though no tooltip were present.
final class MemoWeaverPassiveTooltipAnchorBox {
    weak var view: NSView?
}

private final class MemoWeaverPassiveTooltipAnchorView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

struct MemoWeaverPassiveTooltipAnchor: NSViewRepresentable {
    let box: MemoWeaverPassiveTooltipAnchorBox

    func makeNSView(context: Context) -> NSView {
        let view = MemoWeaverPassiveTooltipAnchorView(frame: .zero)
        box.view = view
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        box.view = view
    }
}
