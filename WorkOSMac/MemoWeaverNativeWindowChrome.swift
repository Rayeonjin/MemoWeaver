import AppKit
import SwiftUI

// v0.9.49: One persistent macOS unified toolbar canvas. Extend only the
// REAL NSSplitView dividers (list/editor and editor/auxiliary) into the titlebar.
// Do not paint the activity rail boundary in the titlebar: unlike the content
// rail divider it is deliberately absent above the window content.
// Native toolbar buttons use the same passive, click-through hints as SwiftUI.
// No NSPopover is created, so the first click always reaches NSButton.action.
private final class MemoWeaverQuickTipButton: NSButton {
    var quickTip: String = ""
    var quickTipEnabled = true {
        didSet {
            if !quickTipEnabled {
                MemoWeaverPassiveTooltipCenter.shared.hide(for: self)
            }
        }
    }
    private var hoverArea: NSTrackingArea?

    override func updateTrackingAreas() {
        if let hoverArea { removeTrackingArea(hoverArea) }
        super.updateTrackingAreas()
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverArea = area
    }
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        guard quickTipEnabled && !quickTip.isEmpty else { return }
        MemoWeaverPassiveTooltipCenter.shared.schedule(
            message: quickTip, anchor: self, owner: self)
    }
    override func mouseExited(with event: NSEvent) {
        MemoWeaverPassiveTooltipCenter.shared.hide(for: self)
        super.mouseExited(with: event)
    }
    override func mouseDown(with event: NSEvent) {
        MemoWeaverPassiveTooltipCenter.shared.hide(for: self)
        super.mouseDown(with: event)
    }
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            MemoWeaverPassiveTooltipCenter.shared.hide(for: self)
        }
        super.viewWillMove(toWindow: newWindow)
    }
}

// Unlike v0.9.42, pane visibility NEVER inserts or removes an
// NSTrackingSeparatorToolbarItem. The v0.9.42 crash report shows AppKit's
// NSWindowSectionController.registerSeparator aborting during that insertion.
// This view measures the REAL pinned NSSplitView frames and positions the
// toolbar controls and divider rules directly over the corresponding panes,
// without touching the split engine, editor, or stored widths.
private final class MemoWeaverDividerOverlay: NSView {
    var separatorXs: [CGFloat] = [] { didSet { needsDisplay = true } }
    var separatorThickness: CGFloat = 1 { didSet { needsDisplay = true } }
    var separatorColor: NSColor = .separatorColor { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        separatorColor.setFill()
        let scale = max(window?.backingScaleFactor ?? 2, 1)
        let width = max(1 / scale, (separatorThickness * scale).rounded() / scale)
        for x in separatorXs where x >= 0 && x < bounds.width {
            let position = (x * scale).rounded() / scale
            NSRect(x: position, y: 0, width: min(width, bounds.maxX - position),
                   height: bounds.height).fill()
        }
    }
}

// The titlebar canvas and the pinned NSSplitView are rendered in different
// AppKit subtrees. Even when both draw a one-pixel divider at the same X,
// macOS can leave a 1-3pt notch where the toolbar meets the content. Fill
// ONLY that tiny junction in window content coordinates; never register an
// NSTrackingSeparatorToolbarItem (which crashed when reopening the list).
private final class MemoWeaverDividerSeamOverlay: NSView {
    var segments: [NSRect] = [] {
        didSet { if oldValue != segments { needsDisplay = true } }
    }
    var dividerColor: NSColor = .separatorColor {
        didSet { needsDisplay = true }
    }
    override var isFlipped: Bool { superview?.isFlipped ?? false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        dividerColor.setFill()
        for segment in segments where segment.intersects(dirtyRect) {
            segment.fill()
        }
    }
}

private final class MemoWeaverToolbarCanvas: NSView {
    var onLayout: ((MemoWeaverToolbarCanvas) -> Void)?
    // Native divider geometry/color are read from the existing NSSplitView;
    // no dynamic NSTrackingSeparatorToolbarItem registration is involved.
    private let dividerOverlay = MemoWeaverDividerOverlay(frame: .zero)
    var separatorXs: [CGFloat] = [] {
        didSet { dividerOverlay.separatorXs = separatorXs }
    }
    var separatorThickness: CGFloat = 1 {
        didSet { dividerOverlay.separatorThickness = separatorThickness }
    }
    var separatorColor: NSColor = .separatorColor {
        didSet { dividerOverlay.separatorColor = separatorColor }
    }
    func placeOverlayAboveControls() {
        dividerOverlay.frame = bounds
        dividerOverlay.autoresizingMask = [.width, .height]
        addSubview(dividerOverlay, positioned: .above, relativeTo: nil)
    }
    private var widthRule: NSLayoutConstraint?
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        let width = widthAnchor.constraint(equalToConstant: frameRect.width)
        width.priority = .defaultHigh  // Compress if the system needs space.
        width.isActive = true
        heightAnchor.constraint(equalToConstant: MemoWeaverToolbarGeometry.canvasHeight).isActive = true
        widthRule = width
    }
    required init?(coder: NSCoder) { fatalError("Toolbar is created programmatically") }
    var desiredWidth: CGFloat = 820 {
        didSet {
            if abs(desiredWidth - oldValue) > 1 {
                widthRule?.constant = desiredWidth
                invalidateIntrinsicContentSize()
            }
        }
    }
    override var isFlipped: Bool { true }
    override var intrinsicContentSize: NSSize {
        NSSize(width: desiredWidth, height: MemoWeaverToolbarGeometry.canvasHeight)
    }
    override func layout() {
        super.layout()
        dividerOverlay.frame = bounds
        onLayout?(self)
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

// Native window expansion runs BEFORE a closed pane is inserted into the
// NSSplitView. Modifying contentMinSize alone does not reliably make an
// already-small window wider, so explicit setFrame is required. Only the
// workspace window's native toolbar is considered; reference windows, sheets,
// the user's preference widths and the editor's NSTextView remain untouched.
enum MemoWeaverPaneWindowSizing {
    static func expandForPaneOpening(listVisible: Bool, rightVisible: Bool,
                                     focusMode: Bool,
                                     preferredListWidth: CGFloat,
                                     preferredRightWidth: CGFloat) {
        let candidates = [NSApp.keyWindow, NSApp.mainWindow].compactMap { $0 }
        let selected = (candidates + NSApp.windows).first {
            $0.toolbar?.identifier == MemoWeaverToolbarItems.toolbarID
        }
        guard let window = selected else { return }
        let required = MemoWeaverToolbarGeometry.minimumContentWidth(
            isNotePage: true, listVisible: listVisible, rightVisible: rightVisible,
            focusMode: focusMode, preferredListWidth: preferredListWidth,
            preferredRightWidth: preferredRightWidth, dividerThickness: 1)
        expand(window: window, requiredContentWidth: required)
    }

    @discardableResult
    static func expand(window: NSWindow, requiredContentWidth: CGFloat) -> Bool {
        // Full-screen/tiled windows and live mouse resize have OS-managed
        // geometry. Never fight those transitions or move another window.
        guard !window.styleMask.contains(.fullScreen), !window.inLiveResize else {
            return false
        }
        let oldFrame = window.frame
        let oldContentWidth = window.contentRect(forFrameRect: oldFrame).width
        guard requiredContentWidth.isFinite,
              requiredContentWidth > oldContentWidth + 0.5 else { return false }
        let frameChromeWidth = max(0, oldFrame.width - oldContentWidth)
        let target = MemoWeaverToolbarGeometry.expansionFrame(
            current: oldFrame, requiredFrameWidth: requiredContentWidth + frameChromeWidth,
            visibleFrame: window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame)
        guard target.width > oldFrame.width + 0.5 else { return false }
        window.setFrame(target, display: true, animate: false)
        return true
    }
}

struct MemoWeaverToolbarSnapshot: Equatable {
    var isNotePage: Bool
    var listVisible: Bool
    var rightVisible: Bool
    var focusMode: Bool
    var hasCurrentNote: Bool
    var noteID: String
    var noteTitle: String
    var notePinned: Bool
    var noteTrashed: Bool
    var isTrashPage: Bool
    var selectedRightTab: String
}

enum MemoWeaverToolbarItems {
    static let toolbarID = NSToolbar.Identifier("MemoWeaver.unified.v0948")
    static let workspace = NSToolbarItem.Identifier("MemoWeaver.toolbar.workspace")
    static let listTitle = NSToolbarItem.Identifier("MemoWeaver.toolbar.listTitle")
    static let listToggle = NSToolbarItem.Identifier("MemoWeaver.toolbar.listToggle")
    static let editorTitle = NSToolbarItem.Identifier("MemoWeaver.toolbar.editorTitle")
    static let newNote = NSToolbarItem.Identifier("MemoWeaver.toolbar.newNote")
    static let pin = NSToolbarItem.Identifier("MemoWeaver.toolbar.pin")
    static let more = NSToolbarItem.Identifier("MemoWeaver.toolbar.more")
    static let focus = NSToolbarItem.Identifier("MemoWeaver.toolbar.focus")
    static let rightToggle = NSToolbarItem.Identifier("MemoWeaver.toolbar.rightToggle")
    static let rightTabs = NSToolbarItem.Identifier("MemoWeaver.toolbar.rightTabs")
    static let quickSearch = NSToolbarItem.Identifier("MemoWeaver.toolbar.quickSearch")

    // Exactly one item is installed for the whole lifetime of the Window.
    // In particular, pane visibility never mutates NSToolbar.items.
    static func order(_ state: MemoWeaverToolbarSnapshot)
        -> [NSToolbarItem.Identifier] { [workspace] }
}

struct MemoWeaverNativeWindowChrome: NSViewRepresentable {
    var snapshot: MemoWeaverToolbarSnapshot

    func makeNSView(context: Context) -> NSView {
        let anchor = WindowAnchor(frame: .zero)
        anchor.snapshot = snapshot
        return anchor
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let anchor = nsView as? WindowAnchor else { return }
        anchor.snapshot = snapshot
        anchor.configureIfAttached()
    }

    // The NSView remains mounted at the window root. NSToolbar.delegate is
    // weak; keeping the anchor alive keeps its delegate and command targets.
    private final class WindowAnchor: NSView, NSToolbarDelegate, NSTextFieldDelegate {
        var snapshot = MemoWeaverToolbarSnapshot(
            isNotePage: true, listVisible: true, rightVisible: false,
            focusMode: false, hasCurrentNote: false, noteID: "", noteTitle: "",
            notePinned: false, noteTrashed: false, isTrashPage: false,
            selectedRightTab: "preview")
        private weak var installedWindow: NSWindow?
        private weak var pinnedSplit: NSSplitView?
        private var managedToolbar: NSToolbar?
        private weak var titleField: NSTextField?
        private var editingNoteID = ""
        private weak var rightTabs: NSSegmentedControl?
        private var controls: [NSToolbarItem.Identifier: NSButton] = [:]
        private weak var listLabel: NSTextField?
        private var toolbarCanvas: MemoWeaverToolbarCanvas?
        private var dividerSeamOverlay: MemoWeaverDividerSeamOverlay?
        private var queuedDiscovery = false
        private weak var observedSplit: NSSplitView?
        private weak var observedWindow: NSWindow?
        // Also catch pane opening caused by restoring focus, switching page or
        // an external state update, which might bypass a direct toolbar tap.
        private var lastVisibility: (note: Bool, list: Bool, right: Bool)?

        deinit {
            dividerSeamOverlay?.removeFromSuperview()
            NotificationCenter.default.removeObserver(self)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            configureIfAttached()
        }

        func configureIfAttached(allowDeferredDiscovery: Bool = true) {
            guard let window else { return }
            window.styleMask.insert(.fullSizeContentView)
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.backgroundColor = .windowBackgroundColor
            window.titlebarSeparatorStyle = .none
            window.toolbarStyle = .unifiedCompact
            // Keep the native titlebar appearance. The traffic lights retain
            // their system-managed position; only split dividers are painted.
            window.isMovableByWindowBackground = false

            // The split may briefly be absent during a SwiftUI pane transition.
            // NEVER register a tracking separator against it.
            pinnedSplit = snapshot.isNotePage ? findPinnedSplit(in: window.contentView) : nil
            if snapshot.isNotePage && pinnedSplit == nil &&
               allowDeferredDiscovery && !queuedDiscovery {
                queuedDiscovery = true
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.queuedDiscovery = false
                    self.configureIfAttached(allowDeferredDiscovery: false)
                }
            }
            configureGeometryObservers(window: window, split: pinnedSplit)
            if installedWindow !== window || window.toolbar !== managedToolbar {
                let toolbar = NSToolbar(identifier: MemoWeaverToolbarItems.toolbarID)
                toolbar.delegate = self
                toolbar.displayMode = .iconOnly
                toolbar.allowsUserCustomization = false
                toolbar.autosavesConfiguration = false
                managedToolbar = toolbar
                installedWindow = window
                window.toolbar = toolbar
            }
            // Install the passive seam overlay during window configuration,
            // never during NSToolbar/NSView layout (reentrant layout is unsafe).
            ensureDividerSeamOverlay(in: window)
            refreshControls()
            updateWindowMinimumSize(window)
            toolbarCanvas?.needsLayout = true
        }

        // Respond to visible panes and their SAVED preferred widths.  The
        // historical fixed 970pt SwiftUI minimum allowed the content toolbar
        // to compress and clip its controls with both side panes visible.
        // NSWindow owns the actual resize limit; SwiftUI does not remount the
        // editor or rewrite the user's widths when the limit changes.
        private func updateWindowMinimumSize(_ window: NSWindow) {
            let store = UserDefaults.standard
            let desired = MemoWeaverToolbarGeometry.minimumContentWidth(
                isNotePage: snapshot.isNotePage,
                listVisible: snapshot.listVisible,
                rightVisible: snapshot.rightVisible,
                focusMode: snapshot.focusMode,
                preferredListWidth: CGFloat(store.double(forKey: "memoweaver.notes.preferredWidth")),
                preferredRightWidth: CGFloat(store.double(forKey: "memoweaver.rightPane.preferredWidth")),
                dividerThickness: pinnedSplit?.dividerThickness ?? 1)
            let before = lastVisibility
            let openedPane = snapshot.isNotePage && (
                before?.note == false ||
                (before?.list == false && snapshot.listVisible) ||
                (before?.right == false && snapshot.rightVisible))
            // A notes-only small window can also become too narrow when the
            // user opens Settings or another full-width workspace page.
            let shouldExpand = before == nil || before?.note != snapshot.isNotePage || openedPane
            // Store the state before setFrame: windowDidResize can re-enter
            // configuration/layout through AppKit's notification observers.
            lastVisibility = (note: snapshot.isNotePage, list: snapshot.listVisible,
                              right: snapshot.rightVisible)
            if shouldExpand {
                MemoWeaverPaneWindowSizing.expand(window: window,
                                                   requiredContentWidth: desired)
            }
            // Do not demand a window wider than its current display's usable
            // width (e.g. a large right-pane preference after disconnecting a
            // big external monitor). In that exceptional case native compact
            // layout remains possible, but no window is forced offscreen.
            let screenWidth = window.screen?.visibleFrame.width ?? desired
            let maximumUsable = max(1, screenWidth)
            let width = min(desired, maximumUsable)
            let target = NSSize(width: width,
                                height: MemoWeaverToolbarGeometry.minimumContentHeight)
            if abs(window.contentMinSize.width - target.width) > 0.5 ||
               abs(window.contentMinSize.height - target.height) > 0.5 {
                window.contentMinSize = target
            }
        }

        private func configureGeometryObservers(window: NSWindow, split: NSSplitView?) {
            if observedWindow !== window {
                if let observedWindow {
                    NotificationCenter.default.removeObserver(self, name: NSWindow.didResizeNotification,
                                                              object: observedWindow)
                }
                NotificationCenter.default.addObserver(self, selector: #selector(geometryChanged(_:)),
                    name: NSWindow.didResizeNotification, object: window)
                observedWindow = window
            }
            if observedSplit !== split {
                if let observedSplit {
                    NotificationCenter.default.removeObserver(self, name: NSSplitView.didResizeSubviewsNotification,
                                                              object: observedSplit)
                }
                if let split {
                    NotificationCenter.default.addObserver(self, selector: #selector(geometryChanged(_:)),
                        name: NSSplitView.didResizeSubviewsNotification, object: split)
                }
                observedSplit = split
            }
        }

        @objc private func geometryChanged(_ notification: Notification) {
            toolbarCanvas?.needsLayout = true
            // Re-evaluate after a divider drag's final width is persisted, not
            // for every mouse-move (which could fight the native drag gesture).
            if NSEvent.pressedMouseButtons & 1 == 0, let window = observedWindow {
                updateWindowMinimumSize(window)
            }
        }

        private func findPinnedSplit(in root: NSView?) -> NSSplitView? {
            guard let root else { return nil }
            if let split = root as? NSSplitView,
               split.identifier?.rawValue == "MemoWeaver.notes.pinnedSplit",
               split.window === window { return split }
            for child in root.subviews {
                if let found = findPinnedSplit(in: child) { return found }
            }
            return nil
        }

        func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            MemoWeaverToolbarItems.order(snapshot)
        }

        func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            [MemoWeaverToolbarItems.workspace]
        }

        func toolbar(_ toolbar: NSToolbar,
                     itemForItemIdentifier identifier: NSToolbarItem.Identifier,
                     willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
            switch identifier {
            case MemoWeaverToolbarItems.workspace:
                let item = NSToolbarItem(itemIdentifier: identifier)
                let canvas = MemoWeaverToolbarCanvas(frame:
                    NSRect(x: 0, y: 0, width: 820, height: 34))
                canvas.onLayout = { [weak self] view in self?.layoutToolbar(in: view) }
                for childID in [MemoWeaverToolbarItems.listTitle, MemoWeaverToolbarItems.newNote,
                                MemoWeaverToolbarItems.listToggle, MemoWeaverToolbarItems.editorTitle, MemoWeaverToolbarItems.pin, MemoWeaverToolbarItems.more,
                                MemoWeaverToolbarItems.focus, MemoWeaverToolbarItems.rightToggle, MemoWeaverToolbarItems.rightTabs, MemoWeaverToolbarItems.quickSearch] {
                    if let child = self.toolbar(toolbar, itemForItemIdentifier: childID,
                                                willBeInsertedIntoToolbar: false),
                       let subview = child.view {
                        canvas.addSubview(subview)
                    }
                }
                canvas.placeOverlayAboveControls()
                toolbarCanvas = canvas
                item.view = canvas
                item.visibilityPriority = .user
                return item
            case MemoWeaverToolbarItems.listTitle:
                let item = NSToolbarItem(itemIdentifier: identifier)
                let label = NSTextField(labelWithString: "MemoWeaver")
                label.font = .systemFont(ofSize: 13, weight: .semibold)
                label.alignment = .left
                label.controlSize = .regular
                label.usesSingleLineMode = true
                label.frame = NSRect(x: 0, y: 0, width: 100,
                                     height: MemoWeaverToolbarGeometry.controlHeight)
                item.view = label
                listLabel = label
                return item
            case MemoWeaverToolbarItems.editorTitle:
                let item = NSToolbarItem(itemIdentifier: identifier)
                let text = NSTextField(frame: NSRect(x: 0, y: 0, width: 145, height: 28))
                text.isBordered = false
                text.drawsBackground = false
                text.isEditable = true
                text.isSelectable = true
                text.focusRingType = .none
                text.usesSingleLineMode = true
                text.lineBreakMode = .byTruncatingTail
                text.font = .systemFont(ofSize: 13, weight: .semibold)
                text.controlSize = .regular
                text.alignment = .left
                text.placeholderString = "메모를 선택하세요"
                text.delegate = self
                item.view = text
                titleField = text
                return item
            case MemoWeaverToolbarItems.rightTabs:
                let item = NSToolbarItem(itemIdentifier: identifier)
                let tabs = NSSegmentedControl(frame: NSRect(x: 0, y: 0, width: 244, height: 28))
                tabs.segmentCount = 4
                tabs.setLabel("미리보기", forSegment: 0)
                tabs.setLabel("연결", forSegment: 1)
                tabs.setLabel("참고", forSegment: 2)
                tabs.setLabel("AI", forSegment: 3)
                tabs.setWidth(85, forSegment: 0)
                tabs.setWidth(51, forSegment: 1)
                tabs.setWidth(65, forSegment: 2)
                tabs.setWidth(43, forSegment: 3)
                tabs.segmentStyle = .rounded
                tabs.trackingMode = .selectOne
                tabs.controlSize = .regular
                tabs.target = self
                tabs.action = #selector(selectRightTab(_:))
                item.view = tabs
                rightTabs = tabs
                return item
            case MemoWeaverToolbarItems.listToggle:
                return iconItem(identifier, label: "메모 목록 열기·닫기", action: #selector(toggleList(_:)),
                                priority: .user)
            case MemoWeaverToolbarItems.rightToggle:
                return iconItem(identifier, label: "보조창 열기·닫기", action: #selector(toggleRight(_:)),
                                priority: .user)
            case MemoWeaverToolbarItems.newNote:
                return iconItem(identifier, label: "새 메모", symbol: "square.and.pencil",
                                action: #selector(createNote(_:)), priority: .user)
            case MemoWeaverToolbarItems.pin:
                return iconItem(identifier, label: "메모 고정", symbol: "pin",
                                action: #selector(togglePin(_:)))
            case MemoWeaverToolbarItems.more:
                return iconItem(identifier, label: "메모 작업", symbol: "ellipsis",
                                action: #selector(showMoreMenu(_:)))
            case MemoWeaverToolbarItems.focus:
                return iconItem(identifier, label: "집중 모드", symbol: "arrow.up.left.and.arrow.down.right",
                                action: #selector(toggleFocus(_:)))
            case MemoWeaverToolbarItems.quickSearch:
                return iconItem(identifier, label: "빠른 검색", symbol: "magnifyingglass",
                                action: #selector(openSearch(_:)))
            default: return nil
            }
        }

        private func iconItem(_ identifier: NSToolbarItem.Identifier,
                              label: String, symbol: String? = nil,
                              action: Selector,
                              priority: NSToolbarItem.VisibilityPriority = .standard) -> NSToolbarItem {
            let item = NSToolbarItem(itemIdentifier: identifier)
            item.label = label
            item.paletteLabel = label
            // The 130ms QuickTipButton owns the tooltip; NSToolbarItem's
            // default hint would otherwise reappear after the system delay.
            item.toolTip = nil
            item.visibilityPriority = priority
            let button = MemoWeaverQuickTipButton(frame: NSRect(x: 0, y: 0,
                            width: MemoWeaverToolbarGeometry.controlWidth,
                            height: MemoWeaverToolbarGeometry.controlHeight))
            button.isBordered = false
            button.controlSize = .regular
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            if let symbol {
                button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
            }
            button.quickTip = label
            button.quickTipEnabled = UserDefaults.standard.object(forKey: "memoweaver.ui.tooltipsEnabled") as? Bool != false
            button.toolTip = nil
            button.target = self
            button.action = action
            button.setAccessibilityLabel(label)
            // Preserve actions when macOS moves a low-priority custom view
            // into the toolbar overflow menu in a narrow window.
            let overflow = NSMenuItem(title: label, action: action, keyEquivalent: "")
            overflow.target = self
            item.menuFormRepresentation = overflow
            controls[identifier] = button
            item.view = button
            return item
        }

        // This is a pure view-frame update: no change to NSToolbar.items,
        // NSWindowSectionController, or NSSplitView.arrangedSubviews.
        // Positions are calculated in the native window coordinate system.
        private func layoutToolbar(in canvas: MemoWeaverToolbarCanvas) {
            guard let window = canvas.window else { return }
            let originX = canvas.convert(.zero, to: nil).x
            let availableWidth = max(280, window.frame.width - originX - 24)
            canvas.desiredWidth = availableWidth
            let viewWidth = canvas.bounds.width
            let showTips = UserDefaults.standard.object(forKey: "memoweaver.ui.tooltipsEnabled") as? Bool != false
            for button in controls.values {
                if let quick = button as? MemoWeaverQuickTipButton {
                    quick.quickTipEnabled = showTips
                    quick.quickTip = button.accessibilityLabel() ?? ""
                } else {
                    button.toolTip = showTips ? button.accessibilityLabel() : nil
                }
            }
            let iconWidth = MemoWeaverToolbarGeometry.controlWidth
            let iconGap: CGFloat = 4
            func hide(_ id: NSToolbarItem.Identifier) {
                controlView(id)?.isHidden = true
            }
            func place(_ id: NSToolbarItem.Identifier, x: CGFloat, width: CGFloat = 30) {
                guard let view = controlView(id) else { return }
                view.isHidden = false
                // NSTextField text is top-aligned WITHIN its frame; an icon
                // uses the center of its frame. Their v0.9.48 28pt frames had
                // matching bounds but visibly different optical baselines.
                // Center the text's native line-height box instead of giving
                // the NSTextField the icon button's tall drawing rectangle.
                let isTitleText = id == MemoWeaverToolbarItems.listTitle ||
                                  id == MemoWeaverToolbarItems.editorTitle
                let height = isTitleText ? MemoWeaverToolbarGeometry.titleTextHeight
                                         : MemoWeaverToolbarGeometry.controlHeight
                let top = isTitleText ? MemoWeaverToolbarGeometry.titleTextOrigin
                                      : MemoWeaverToolbarGeometry.verticalOrigin
                view.frame = NSRect(x: floor(x), y: top,
                                    width: max(1, floor(width)), height: height)
            }
            if !snapshot.isNotePage {
                canvas.separatorXs = []
                dividerSeamOverlay?.segments = []
                for id in [MemoWeaverToolbarItems.listTitle, MemoWeaverToolbarItems.listToggle,
                           MemoWeaverToolbarItems.editorTitle, MemoWeaverToolbarItems.pin, MemoWeaverToolbarItems.more, MemoWeaverToolbarItems.focus, MemoWeaverToolbarItems.rightToggle,
                           MemoWeaverToolbarItems.rightTabs] { hide(id) }
                place(MemoWeaverToolbarItems.newNote, x: 5)
                place(MemoWeaverToolbarItems.quickSearch, x: viewWidth - 34)
                return
            }
            hide(MemoWeaverToolbarItems.quickSearch)
            let split = pinnedSplit
            let children: [NSView] = split?.arrangedSubviews ?? []
            let expected = 1 + (snapshot.listVisible ? 1 : 0) + (snapshot.rightVisible ? 1 : 0)
            let valid = children.count == expected && split?.window === window
            func viewX(_ value: CGFloat) -> CGFloat {
                guard let split else { return value }
                return split.convert(NSPoint(x: value, y: 0), to: nil).x - originX
            }
            // These are live split edges, NOT UserDefaults or magic fixed pane
            // widths; reopening the list does not discard a dragged preference.
            let leftEdge: CGFloat = snapshot.listVisible
                ? (valid ? viewX(children[1].frame.minX) : min(270, viewWidth * 0.27))
                : 0
            let rightEdge: CGFloat = snapshot.rightVisible
                ? (valid ? viewX(children[expected - 1].frame.minX) : max(350, viewWidth - 340))
                : viewWidth
            let editorLeft = max(0, leftEdge)
            let editorRight = min(viewWidth, max(editorLeft + 185, rightEdge))
            // The rail boundary is NEVER a native titlebar rule. Only actual
            // NSSplitView dividers are extended upward, at exactly their native
            // X coordinates, width, and color. A temporarily missing split
            // paints no lines rather than guessing a stale divider position.
            if valid, let split {
                canvas.separatorThickness = split.dividerThickness
                canvas.separatorColor = split.dividerColor
                canvas.separatorXs = MemoWeaverToolbarGeometry.dividerOrigins(
                    listPaneStart: snapshot.listVisible ? viewX(children[1].frame.minX) : nil,
                    auxiliaryPaneStart: snapshot.rightVisible ? viewX(children[expected - 1].frame.minX) : nil,
                    thickness: split.dividerThickness)
            } else {
                canvas.separatorXs = []
            }
            // Update after the real pane frames are known. It paints no
            // vertical line inside the navigation rail, and its hit test is
            // permanently disabled so divider dragging is unaffected.
            updateDividerSeam(canvas: canvas, window: window,
                              split: valid ? split : nil)

            if snapshot.listVisible {
                place(MemoWeaverToolbarItems.listTitle, x: 6, width: min(105, max(50, leftEdge - 52)))
                place(MemoWeaverToolbarItems.newNote, x: max(115, leftEdge - 37))
            } else {
                hide(MemoWeaverToolbarItems.listTitle)
            }
            let toggleX = editorLeft + 8
            place(MemoWeaverToolbarItems.listToggle, x: toggleX)
            let actionCount: CGFloat = snapshot.listVisible ? 4 : 5
            let actionWidth = actionCount * iconWidth + (actionCount - 1) * iconGap
            let actionStart = max(toggleX + 80, editorRight - 9 - actionWidth)
            let actionIDs: [NSToolbarItem.Identifier] = snapshot.listVisible
                ? [MemoWeaverToolbarItems.pin, MemoWeaverToolbarItems.more, MemoWeaverToolbarItems.focus, MemoWeaverToolbarItems.rightToggle]
                : [MemoWeaverToolbarItems.newNote, MemoWeaverToolbarItems.pin, MemoWeaverToolbarItems.more, MemoWeaverToolbarItems.focus, MemoWeaverToolbarItems.rightToggle]
            for (idx, id) in actionIDs.enumerated() {
                place(id, x: actionStart + CGFloat(idx) * (iconWidth + iconGap))
            }
            let titleX = toggleX + 38
            let titleWidth = max(42, min(270, actionStart - titleX - 8))
            place(MemoWeaverToolbarItems.editorTitle, x: titleX, width: titleWidth)

            if snapshot.rightVisible {
                let tabsX = rightEdge + 10
                let tabWidth = max(0, min(244, viewWidth - tabsX - 8))
                if tabWidth >= 170 {
                    if let tabs = rightTabs {
                        let compact = tabWidth < 221
                        let firstLabel = compact ? "미리" : "미리보기"
                        if tabs.label(forSegment: 0) != firstLabel {
                            tabs.setLabel(firstLabel, forSegment: 0)
                        }
                        let scale = tabWidth / 244
                        for (index, base) in [85.0, 51.0, 65.0, 43.0].enumerated() {
                            let target = CGFloat(base) * scale
                            if abs(tabs.width(forSegment: index) - target) > 1 {
                                tabs.setWidth(target, forSegment: index)
                            }
                        }
                    }
                    place(MemoWeaverToolbarItems.rightTabs, x: tabsX, width: tabWidth)
                } else {
                    hide(MemoWeaverToolbarItems.rightTabs)
                }
            } else {
                hide(MemoWeaverToolbarItems.rightTabs)
            }
        }

        private func ensureDividerSeamOverlay(in window: NSWindow) {
            guard let content = window.contentView else { return }
            if dividerSeamOverlay?.superview === content { return }
            dividerSeamOverlay?.removeFromSuperview()
            let overlay = MemoWeaverDividerSeamOverlay(frame: content.bounds)
            overlay.autoresizingMask = [.width, .height]
            content.addSubview(overlay, positioned: .above, relativeTo: nil)
            dividerSeamOverlay = overlay
        }

        private func updateDividerSeam(canvas: MemoWeaverToolbarCanvas,
                                       window: NSWindow, split: NSSplitView?) {
            guard let split, !canvas.separatorXs.isEmpty,
                  let content = window.contentView else {
                dividerSeamOverlay?.segments = []
                return
            }
            // Layout is read-only: the overlay's presence is ensured in
            // configureIfAttached, so no child view is added during layout.
            guard let seam = dividerSeamOverlay,
                  seam.superview === content else { return }
            if seam.frame != content.bounds { seam.frame = content.bounds }
            let toolbarRect = canvas.convert(canvas.bounds, to: seam)
            let splitRect = split.convert(split.bounds, to: seam)
            // Full-size-content windows can flip either coordinate space.
            // Convert both rectangles to this ONE overlay before measuring.
            let toolbarBottom = seam.isFlipped ? toolbarRect.maxY : toolbarRect.minY
            let paneTop = seam.isFlipped ? splitRect.minY : splitRect.maxY
            let gap = abs(paneTop - toolbarBottom)
            // If the views are in unrelated layout phases, do not draw an
            // orphaned rule across arbitrary window content.
            guard gap.isFinite, gap <= 18 else { seam.segments = []; return }
            let scale = max(1, window.backingScaleFactor)
            let pixel = 1 / scale
            let y = (min(toolbarBottom, paneTop) / pixel).rounded() * pixel - pixel
            let height = max(2 * pixel, (gap / pixel).rounded() * pixel + 2 * pixel)
            let thickness = max(pixel,
                                (split.dividerThickness / pixel).rounded() * pixel)
            seam.dividerColor = split.dividerColor
            seam.segments = canvas.separatorXs.compactMap { x in
                let point = canvas.convert(NSPoint(x: x, y: 0), to: seam)
                guard point.x.isFinite, point.x >= -thickness,
                      point.x <= seam.bounds.maxX + thickness else { return nil }
                return NSRect(x: (point.x / pixel).rounded() * pixel,
                              y: y, width: thickness, height: height)
            }
        }

        private func controlView(_ id: NSToolbarItem.Identifier) -> NSView? {
            switch id {
            case MemoWeaverToolbarItems.listTitle: return listLabel
            case MemoWeaverToolbarItems.editorTitle: return titleField
            case MemoWeaverToolbarItems.rightTabs: return rightTabs
            default: return controls[id]
            }
        }

        private func refreshControls() {
            listLabel?.stringValue = snapshot.isTrashPage ? "휴지통" : "MemoWeaver"
            if let titleField {
                titleField.isEnabled = snapshot.hasCurrentNote
                if titleField.currentEditor() == nil && titleField.stringValue != snapshot.noteTitle {
                    titleField.stringValue = snapshot.noteTitle
                }
            }
            updateToggle(MemoWeaverToolbarItems.listToggle, open: snapshot.listVisible, left: true,
                         tip: snapshot.listVisible ? "메모 목록 닫기 (⌘⌥B)" : "메모 목록 열기 (⌘⌥B)")
            updateToggle(MemoWeaverToolbarItems.rightToggle, open: snapshot.rightVisible, left: false,
                         tip: snapshot.rightVisible ? "보조창 닫기 (⌘⌥R)" : "보조창 열기 (⌘⌥R)")
            updateButton(MemoWeaverToolbarItems.pin,
                         image: snapshot.notePinned ? "pin.fill" : "pin",
                         tip: snapshot.notePinned ? "메모 고정 해제" : "메모 고정",
                         enabled: snapshot.hasCurrentNote)
            updateButton(MemoWeaverToolbarItems.focus,
                         image: snapshot.focusMode ? "arrow.down.right.and.arrow.up.left" :
                             "arrow.up.left.and.arrow.down.right",
                         tip: snapshot.focusMode ? "집중 모드 종료 (⌘⌥F)" : "집중 모드 (⌘⌥F)",
                         enabled: snapshot.hasCurrentNote)
            controls[MemoWeaverToolbarItems.more]?.isEnabled = snapshot.hasCurrentNote
            controls[MemoWeaverToolbarItems.rightToggle]?.isEnabled = snapshot.hasCurrentNote
            let selected: Int
            switch snapshot.selectedRightTab {
            case "memory": selected = 1
            case "reference": selected = 2
            case "assistant": selected = 3
            default: selected = 0
            }
            rightTabs?.selectedSegment = selected
            toolbarCanvas?.needsLayout = true
        }

        private func updateToggle(_ identifier: NSToolbarItem.Identifier,
                                  open: Bool, left: Bool, tip: String) {
            guard let button = controls[identifier] else { return }
            button.image = paneGlyph(left: left, open: open)
            button.toolTip = UserDefaults.standard.object(forKey: "memoweaver.ui.tooltipsEnabled") as? Bool == false ? nil : tip
            button.setAccessibilityLabel(tip)
        }

        // Vector image means the right-close glyph never depends on a missing
        // SF Symbol on macOS 14, including open/closed/focus transitions.
        private func paneGlyph(left: Bool, open: Bool) -> NSImage {
            NSImage(size: NSSize(width: 18, height: 16), flipped: false) { _ in
                let outer = NSRect(x: 1.5, y: 1.5, width: 15, height: 13)
                NSColor.labelColor.withAlphaComponent(0.78).setStroke()
                let outline = NSBezierPath(roundedRect: outer, xRadius: 2, yRadius: 2)
                outline.lineWidth = 1.2
                outline.stroke()
                NSColor.labelColor.withAlphaComponent(open ? 0.75 : 0.25).setFill()
                let x: CGFloat = left ? 3.7 : 11.3
                NSRect(x: x, y: 3.0, width: 3.0, height: 10.0).fill()
                return true
            }
        }

        private func updateButton(_ identifier: NSToolbarItem.Identifier,
                                  image: String, tip: String, enabled: Bool) {
            guard let button = controls[identifier] else { return }
            button.image = NSImage(systemSymbolName: image, accessibilityDescription: tip)
            button.toolTip = UserDefaults.standard.object(forKey: "memoweaver.ui.tooltipsEnabled") as? Bool == false ? nil : tip
            button.isEnabled = enabled
            button.setAccessibilityLabel(tip)
        }

        func controlTextDidBeginEditing(_ notice: Notification) {
            editingNoteID = snapshot.noteID
        }

        func controlTextDidChange(_ notice: Notification) {
            guard let field = notice.object as? NSTextField, field === titleField,
                  !editingNoteID.isEmpty else { return }
            // NSControl.currentEditor() is typed as NSText?, even though AppKit
            // supplies an NSTextView field editor. NSText has no hasMarkedText().
            // Do not persist partial Korean/Japanese IME composition text.
            if let editor = field.currentEditor() as? NSTextView, editor.hasMarkedText() {
                return
            }
            postEditorCommand("title", noteID: editingNoteID, value: field.stringValue)
        }

        func controlTextDidEndEditing(_ notice: Notification) {
            guard let field = notice.object as? NSTextField, field === titleField,
                  !editingNoteID.isEmpty else { return }
            postEditorCommand("title", noteID: editingNoteID, value: field.stringValue)
            editingNoteID = ""
        }

        private func postEditorCommand(_ action: String, noteID: String? = nil,
                                       value: String? = nil) {
            guard snapshot.hasCurrentNote || (action == "title" && noteID != nil) else { return }
            var info: [String: String] = ["action": action, "noteID": noteID ?? snapshot.noteID]
            if let value { info["value"] = value }
            NotificationCenter.default.post(name: .memoWeaverNativeEditorCommand,
                                            object: nil, userInfo: info)
        }

        @objc private func toggleList(_ sender: Any?) {
            NotificationCenter.default.post(name: .memoWeaverToggleNoteList, object: nil)
        }
        @objc private func toggleRight(_ sender: Any?) {
            NotificationCenter.default.post(name: .memoWeaverToggleRightPane, object: nil)
        }
        @objc private func toggleFocus(_ sender: Any?) {
            NotificationCenter.default.post(name: .memoWeaverToggleFocusMode, object: nil)
        }
        @objc private func createNote(_ sender: Any?) {
            NotificationCenter.default.post(name: .memoWeaverCreateNewNote, object: nil)
        }
        @objc private func togglePin(_ sender: Any?) {
            postEditorCommand("pin")
        }
        @objc private func openSearch(_ sender: Any?) {
            NotificationCenter.default.post(name: .memoWeaverOpenQuickSearch, object: nil)
        }
        @objc private func selectRightTab(_ sender: NSSegmentedControl) {
            let tab: String
            switch sender.selectedSegment {
            case 1: tab = "memory"
            case 2: tab = "reference"
            case 3: tab = "assistant"
            default: tab = "preview"
            }
            NotificationCenter.default.post(name: .memoWeaverSelectRightPaneTab, object: nil,
                                            userInfo: ["tab": tab])
        }

        @objc private func showMoreMenu(_ sender: Any?) {
            guard snapshot.hasCurrentNote else { return }
            let menu = NSMenu(title: "메모 작업")
            menuItem(menu, "연결된 일정 · 메모 상세 정보…", command: "details")
            menuItem(menu, snapshot.noteTrashed ? "휴지통에서 복원" : "휴지통으로 이동…",
                     command: snapshot.noteTrashed ? "restore" : "trash")
            menu.addItem(.separator())
            menuItem(menu, "변경 이력 체크포인트 (⌘S)", command: "checkpoint")
            menuItem(menu, "변경 이력 보기", command: "history")
            menuItem(menu, "긴 메모 구간 분석", command: "memory")
            menu.addItem(.separator())
            menuItem(menu, "Markdown 내보내기", command: "exportMarkdown")
            menuItem(menu, "HTML 내보내기", command: "exportHTML")
            menuItem(menu, "PDF 내보내기", command: "exportPDF")
            popUp(menu, from: sender, fallback: MemoWeaverToolbarItems.more)
        }

        private func menuItem(_ menu: NSMenu, _ title: String, command: String) {
            let item = NSMenuItem(title: title, action: #selector(noteMenuSelected(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = command
            menu.addItem(item)
        }
        @objc private func noteMenuSelected(_ sender: NSMenuItem) {
            guard let action = sender.representedObject as? String else { return }
            postEditorCommand(action)
        }

        private func popUp(_ menu: NSMenu, from sender: Any?,
                           fallback: NSToolbarItem.Identifier) {
            if let button = sender as? NSButton, button.window != nil {
                menu.popUp(positioning: nil, at: NSPoint(x: 0, y: -4), in: button)
            } else if let view = controls[fallback], view.window != nil {
                menu.popUp(positioning: nil, at: NSPoint(x: 0, y: -4), in: view)
            } else if let event = NSApp.currentEvent, let content = window?.contentView {
                NSMenu.popUpContextMenu(menu, with: event, for: content)
            }
        }


    }
}
