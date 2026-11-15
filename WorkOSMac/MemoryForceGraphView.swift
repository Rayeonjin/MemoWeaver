import AppKit
import SwiftUI

@MainActor final class MemoryGraphControls: ObservableObject {
    @Published var percent = 100
    @Published var busy = false
    @Published var failed = false
    weak var view: MemoryForceGraphView?
}

struct MemoryGraphCanvas: View {
    let data: MemoryGraphData
    let selectedID: String
    let linkingFrom: String
    let onSelect: (String) -> Void
    var onSelectEdge: (String) -> Void = { _ in }
    @StateObject private var controls = MemoryGraphControls()

    static func color(_ group: Int) -> Color { Color(nsColor: MemoryForceGraphView.color(group)) }
    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 9) {
                Button { controls.view?.zoom(by: 1 / 1.25) } label: { Image(systemName: "minus.magnifyingglass") }
                    .help("지도 축소").accessibilityLabel("지도 축소")
                Text("\(controls.percent)%").font(.caption.monospacedDigit()).frame(width: 43)
                Button { controls.view?.zoom(by: 1.25) } label: { Image(systemName: "plus.magnifyingglass") }
                    .help("지도 확대").accessibilityLabel("지도 확대")
                Button("전체 맞춤") { controls.view?.fitToContent() }
                Button("배치 초기화") { controls.view?.resetLayout() }
                    .help("드래그한 위치를 해제하고 d3-force로 다시 배치합니다.")
                if controls.busy { ProgressView().controlSize(.mini) }
                if controls.failed { Text("배치 엔진을 읽지 못해 기본 위치를 표시합니다.").font(.caption).foregroundStyle(.secondary) }
                Spacer(minLength: 0)
                Text("빈 공간 드래그: 이동 · 노드 드래그: 배치 · 휠/핀치: 확대")
                    .font(.caption2).foregroundStyle(.secondary)
            }.controlSize(.small)
            MemoryForceGraphRepresentable(data: data, selectedID: selectedID, linkingFrom: linkingFrom,
                controls: controls, onSelect: onSelect, onSelectEdge: onSelectEdge)
                .frame(minHeight: 180)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

private struct MemoryForceGraphRepresentable: NSViewRepresentable {
    let data: MemoryGraphData
    let selectedID: String
    let linkingFrom: String
    let controls: MemoryGraphControls
    let onSelect: (String) -> Void
    let onSelectEdge: (String) -> Void
    func makeNSView(context: Context) -> MemoryForceGraphView {
        let view = MemoryForceGraphView(frame: .zero)
        view.controls = controls; controls.view = view
        return view
    }
    func updateNSView(_ view: MemoryForceGraphView, context: Context) {
        view.onSelect = onSelect; view.onSelectEdge = onSelectEdge
        view.update(data: data, selectedID: selectedID, linkingFrom: linkingFrom)
    }
    static func dismantleNSView(_ view: MemoryForceGraphView, coordinator: ()) { view.cancelLayout() }
}

private final class MemoryGraphAccessibilityButton: NSAccessibilityElement {
    var press: (() -> Void)?
    override func accessibilityPerformPress() -> Bool { press?(); return true }
}

@MainActor final class MemoryForceGraphView: NSView {
    weak var controls: MemoryGraphControls?
    var onSelect: (String) -> Void = { _ in }
    var onSelectEdge: (String) -> Void = { _ in }
    private(set) var data = MemoryGraphData()
    private(set) var viewport = MemoryGraphViewport()
    private(set) var positions: [String: CGPoint] = [:]
    private(set) var pinned: [String: CGPoint] = [:]
    private(set) var layoutPending = false
    private var selectedID = ""
    private var selectedEdgeID = ""
    private var linkingFrom = ""
    private var topology = ""
    private var generation = 0
    private var work: DispatchWorkItem?
    private var wantsFit = true
    private var down: CGPoint?
    private var previous: CGPoint = .zero
    private var draggedNode: String?
    private var moved = false
    private var hoverID: String?
    private var tracking: NSTrackingArea?
    private var accessibilityButtons: [String: MemoryGraphAccessibilityButton] = [:]
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    static func color(_ group: Int) -> NSColor {
        let palette: [NSColor] = [.systemBlue, .systemTeal, .systemOrange, .systemPurple, .systemPink, .systemMint, .systemIndigo, .systemBrown]
        return palette[Int(group.magnitude % UInt(palette.count))]
    }
    func update(data: MemoryGraphData, selectedID: String, linkingFrom: String) {
        let key = data.nodes.map(\.id).sorted().joined(separator: "\u{1f}") + "\u{1e}" + data.edges.map(\.id).sorted().joined(separator: "\u{1f}")
        self.data = data; self.selectedID = selectedID; self.linkingFrom = linkingFrom
        if key != topology {
            topology = key
            let ids = Set(data.nodes.map(\.id))
            positions = positions.filter { ids.contains($0.key) }
            pinned = pinned.filter { ids.contains($0.key) }
            for (index, node) in data.nodes.sorted(by: { $0.id < $1.id }).enumerated() where positions[node.id] == nil {
                let angle = Double(index) * 2.399963229728653
                let radius = 100 + 22 * sqrt(Double(index))
                positions[node.id] = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            }
            requestLayout()
        }
        needsDisplay = true
    }
    func cancelLayout() { generation += 1; work?.cancel(); work = nil; layoutPending = false }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { cancelLayout() }
    }
    private func requestLayout() {
        cancelLayout()
        let token = generation
        layoutPending = true
        let input = MemoryForceInput(nodes: data.nodes.compactMap { node in
            positions[node.id].map { MemoryForcePoint(id: node.id, x: $0.x, y: $0.y) }
        }, links: data.edges.map { MemoryForceEdge(source: $0.first, target: $0.second) },
        pinned: pinned.map { MemoryForcePoint(id: $0.key, x: $0.value.x, y: $0.value.y) })
        // Defer publication past NSViewRepresentable.updateNSView.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.generation == token else { return }
            self.controls?.busy = true
        }
        let job = DispatchWorkItem {
            let result = Result { try MemoryForceLayout.solve(input) }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == token else { return }
                self.layoutPending = false
                self.controls?.busy = false
                switch result {
                case .success(let points):
                    self.positions = Dictionary(uniqueKeysWithValues: points.map { ($0.id, CGPoint(x: $0.x, y: $0.y)) })
                    self.controls?.failed = false
                case .failure: self.controls?.failed = true
                }
                if self.wantsFit && self.bounds.width > 0 && self.bounds.height > 0 { self.fitToContent() }
                self.needsDisplay = true
            }
        }
        work = job
        MemoryForceLayout.queue.asyncAfter(deadline: .now() + 0.02, execute: job)
    }
    func resetLayout() {
        pinned = [:]; wantsFit = true
        requestLayout()
    }
    func fitToContent() {
        viewport.fit(Array(positions.values), size: bounds.size)
        wantsFit = false; publishScale(); needsDisplay = true
    }
    func zoom(by factor: CGFloat, anchor: CGPoint? = nil) {
        viewport.zoom(by: factor, anchor: anchor ?? CGPoint(x: bounds.midX,y: bounds.midY), size: bounds.size)
        wantsFit = false; publishScale(); needsDisplay = true
    }
    private func publishScale() { controls?.percent = Int((viewport.scale * 100).rounded()) }
    func viewPoint(_ world: CGPoint) -> CGPoint { viewport.viewPoint(world, size: bounds.size) }
    private func worldPoint(_ point: CGPoint) -> CGPoint { viewport.worldPoint(point, size: bounds.size) }
    private func nodeRect(_ id: String) -> CGRect {
        guard let position = positions[id] else { return .zero }
        let point = viewPoint(position)
        return CGRect(x: point.x - 70 * viewport.scale, y: point.y - 17 * viewport.scale,
                      width: 140 * viewport.scale, height: 53 * viewport.scale)
    }
    private func edgeRect(_ edge: MemoryGraphEdge) -> CGRect {
        guard let a = positions[edge.first], let b = positions[edge.second] else { return .zero }
        let point = viewPoint(CGPoint(x: (a.x + b.x)/2, y: (a.y + b.y)/2))
        return CGRect(x: point.x - 45 * viewport.scale,y: point.y - 10 * viewport.scale,
                      width: 90 * viewport.scale,height: 20 * viewport.scale)
    }
    private func node(at point: CGPoint) -> String? { data.nodes.reversed().first { nodeRect($0.id).contains(point) }?.id }
    private func edge(at point: CGPoint) -> String? { data.edges.reversed().first { edgeRect($0).contains(point) }?.id }
    private func label(_ edge: MemoryGraphEdge) -> String {
        edge.confirmed ? ReferencePanelCore.manualLabel(edge.manualKind) : edge.inferredType
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        for edge in data.edges {
            guard let a = positions[edge.first], let b = positions[edge.second] else { continue }
            let av = viewPoint(a), bv = viewPoint(b)
            let highlighted = edge.id == selectedEdgeID || edge.first == hoverID || edge.second == hoverID
            let path = NSBezierPath(); path.move(to: av); path.line(to: bv)
            path.lineWidth = max(0.8, (highlighted ? 2.8 : 1.5) * viewport.scale)
            if !edge.confirmed { path.setLineDash([4,4], count: 2, phase: 0) }
            (edge.confirmed ? NSColor.controlAccentColor : .systemTeal).withAlphaComponent(highlighted ? 1 : 0.55).setStroke()
            path.stroke()
            if let relation = edge.inference, !["same_case","related_case"].contains(relation.relationType),
               let from = positions[relation.fromID], let to = positions[relation.toID] {
                drawArrow(from: viewPoint(from), to: viewPoint(to))
            }
            if viewport.scale >= 0.45 || highlighted {
                let rect = edgeRect(edge)
                NSColor.controlBackgroundColor.withAlphaComponent(0.94).setFill()
                NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7).fill()
                drawText(label(edge), rect: rect.insetBy(dx: 3, dy: 2), size: max(8, 10 * viewport.scale), color: .secondaryLabelColor)
            }
        }
        for node in data.nodes {
            guard let world = positions[node.id] else { continue }
            let point = viewPoint(world), radius = (node.id == selectedID ? 13.0 : 10.0) * viewport.scale
            let circle = CGRect(x: point.x-radius,y: point.y-radius,width:2*radius,height:2*radius)
            Self.color(node.cluster).withAlphaComponent(node.id == hoverID ? 1 : 0.8).setFill()
            NSBezierPath(ovalIn: circle).fill()
            if node.id == selectedID || node.id == linkingFrom {
                NSColor.controlAccentColor.setStroke()
                let outline = NSBezierPath(ovalIn:circle.insetBy(dx:-4,dy:-4)); outline.lineWidth = 2; outline.stroke()
            }
            if viewport.scale >= 0.45 || node.id == selectedID || node.id == hoverID {
                drawText(node.title, rect: CGRect(x: point.x - 68*viewport.scale,y: point.y + 17*viewport.scale,
                    width:136*viewport.scale,height:32*viewport.scale),size:max(8,12*viewport.scale), color:.labelColor)
            }
        }
    }
    private func drawText(_ text: String, rect: CGRect, size: CGFloat, color: NSColor) {
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center; paragraph.lineBreakMode = .byTruncatingTail
        (text as NSString).draw(in:rect,withAttributes:[.font:NSFont.systemFont(ofSize:size),.foregroundColor:color,.paragraphStyle:paragraph])
    }
    private func drawArrow(from: CGPoint, to: CGPoint) {
        let dx = to.x-from.x, dy = to.y-from.y, length = hypot(dx,dy)
        guard length > 1 else { return }
        let ux = dx/length, uy = dy/length, back = 18*viewport.scale, side = 5*viewport.scale
        let tip = CGPoint(x:to.x-ux*back,y:to.y-uy*back)
        let arrow = NSBezierPath(); arrow.move(to:tip)
        arrow.line(to:CGPoint(x:tip.x-ux*side*2-uy*side,y:tip.y-uy*side*2+ux*side))
        arrow.line(to:CGPoint(x:tip.x-ux*side*2+uy*side,y:tip.y-uy*side*2-ux*side)); arrow.close()
        NSColor.systemTeal.setFill(); arrow.fill()
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect:.zero,options:[.activeInKeyWindow,.mouseMoved,.mouseEnteredAndExited,.inVisibleRect],owner:self)
        addTrackingArea(area); tracking = area
    }
    override func mouseMoved(with event: NSEvent) {
        hoverID = node(at:convert(event.locationInWindow,from:nil)); needsDisplay = true
        toolTip = data.nodes.first { $0.id == hoverID }?.title
    }
    override func mouseExited(with event: NSEvent) { hoverID = nil; needsDisplay = true }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow,from:nil)
        down = point; previous = point; moved = false; draggedNode = node(at:point)
    }
    override func mouseDragged(with event: NSEvent) {
        guard let down else { return }
        let point = convert(event.locationInWindow,from:nil)
        if hypot(point.x-down.x,point.y-down.y) >= 4 { moved = true }
        guard moved else { return }
        if let id = draggedNode {
            // A simple click must not cancel an in-flight initial layout.
            // Cancel only once actual dragging starts, then settle on release.
            cancelLayout(); controls?.busy = false
            positions[id] = worldPoint(point); pinned[id] = positions[id]
        }
        else {
            viewport.translation.x += point.x-previous.x; viewport.translation.y += point.y-previous.y
        }
        previous = point; wantsFit = false; needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        guard down != nil else { return }
        let point = convert(event.locationInWindow,from:nil)
        let id = draggedNode
        down = nil; draggedNode = nil
        if moved { if id != nil { requestLayout() }; return }
        if let id { onSelect(id) }
        else if let edge = edge(at:point) { selectedEdgeID = edge; onSelectEdge(edge); needsDisplay = true }
    }
    override func scrollWheel(with event: NSEvent) {
        if !event.hasPreciseScrollingDeltas || event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) {
            zoom(by: exp(event.scrollingDeltaY * 0.035),anchor:convert(event.locationInWindow,from:nil))
        } else {
            viewport.translation.x += event.scrollingDeltaX; viewport.translation.y += event.scrollingDeltaY
            wantsFit = false; needsDisplay = true
        }
    }
    override func magnify(with event: NSEvent) { zoom(by:exp(event.magnification),anchor:convert(event.locationInWindow,from:nil)) }
    override func smartMagnify(with event: NSEvent) { fitToContent() }
    override func keyDown(with event: NSEvent) {
        switch event.charactersIgnoringModifiers {
        case "+", "=": zoom(by:1.25)
        case "-": zoom(by:1/1.25)
        case "0": fitToContent()
        default: super.keyDown(with:event)
        }
    }
    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityLabel() -> String? { "업무 관계 지도 · 확대와 드래그 탐색" }
    override func accessibilityChildren() -> [Any]? {
        var result: [NSAccessibilityElement] = []
        var current: [String: MemoryGraphAccessibilityButton] = [:]
        func button(_ key: String, _ label: String, rect: CGRect, action: @escaping () -> Void) {
            let element = accessibilityButtons[key] ?? MemoryGraphAccessibilityButton()
            element.setAccessibilityElement(true)
            element.setAccessibilityEnabled(true)
            element.setAccessibilityRole(.button); element.setAccessibilityLabel(label)
            element.setAccessibilityParent(self)
            if let window { element.setAccessibilityFrame(window.convertToScreen(convert(rect,to:nil))) }
            element.press = action; result.append(element); current[key] = element
        }
        for node in data.nodes {
            button("node:" + node.id, node.title,rect:nodeRect(node.id)) { [weak self] in self?.onSelect(node.id) }
        }
        let titles = Dictionary(uniqueKeysWithValues: data.nodes.map { ($0.id, $0.title) })
        for edge in data.edges {
            let name = label(edge) + " · " + (titles[edge.first] ?? edge.first) + " · " + (titles[edge.second] ?? edge.second)
            button("edge:" + edge.id, name + " · 원문 근거 확인",rect:edgeRect(edge)) { [weak self] in
                self?.selectedEdgeID = edge.id; self?.onSelectEdge(edge.id); self?.needsDisplay = true
            }
        }
        // AppKit requires the vendor to retain virtual accessibility elements
        // for as long as their UI exists. Keep stable identities across queries.
        accessibilityButtons = current
        return result
    }
}
