import AppKit

@MainActor enum D3ForceNativeChecks {
    static func find(_ view: NSView) -> MemoryForceGraphView? {
        if let view = view as? MemoryForceGraphView { return view }
        for child in view.subviews { if let found = find(child) { return found } }
        return nil
    }
    static func wait(_ view: MemoryForceGraphView) {
        let end = Date().addingTimeInterval(8)
        while view.layoutPending && Date() < end { UsabilityNativeSmoke.pump(0.02) }
        precondition(!view.layoutPending,"background force layout did not finish")
    }
    static func run(host: NSView, model: WorkOSModel, window: NSWindow) {
        UsabilityNativeSmoke.pump()
        guard let view = find(host) else { preconditionFailure("native force map missing") }
        wait(view)
        precondition(view.positions.count == view.data.nodes.count)
        let relations = model.memoryGraph.edges.map { ($0.id,$0.inference?.fromQuote,$0.inference?.toQuote) }
        let scale = view.viewport.scale
        view.zoom(by:1.25); precondition(view.viewport.scale>scale)
        view.zoom(by:1/1.25); precondition(abs(view.viewport.scale-scale)<0.0001)
        let first = view.data.nodes[0].id
        let point = view.viewPoint(view.positions[first]!)
        func mouse(_ type: NSEvent.EventType, _ point: CGPoint) -> NSEvent {
            NSEvent.mouseEvent(with:type,location:view.convert(point,to:nil),modifierFlags:[],timestamp:0,
                windowNumber:window.windowNumber,context:nil,eventNumber:1,clickCount:1,pressure:1)!
        }
        // Native event methods on a disposable test window; no system event injection.
        view.mouseDown(with:mouse(.leftMouseDown,point))
        let end = CGPoint(x:point.x+90,y:point.y+45)
        view.mouseDragged(with:mouse(.leftMouseDragged,end))
        view.mouseUp(with:mouse(.leftMouseUp,end))
        let pin = view.pinned[first]!
        wait(view)
        precondition(hypot(view.positions[first]!.x-pin.x,view.positions[first]!.y-pin.y)<0.0001,"dragged position lost")
        let translation = view.viewport.translation
        let blank = CGPoint(x:4,y:4), blankEnd = CGPoint(x:34,y:29)
        view.mouseDown(with:mouse(.leftMouseDown,blank))
        view.mouseDragged(with:mouse(.leftMouseDragged,blankEnd))
        view.mouseUp(with:mouse(.leftMouseUp,blankEnd))
        precondition(view.viewport.translation.x==translation.x+30 && view.viewport.translation.y==translation.y+25)
        precondition(view.isAccessibilityElement() && view.accessibilityRole() == .group,
                     "map container must be exposed to the actual accessibility tree")
        let buttons = view.accessibilityChildren() ?? []
        precondition(buttons.count == view.data.nodes.count+view.data.edges.count, "map controls must remain accessible")
        let again = view.accessibilityChildren() ?? []
        precondition((buttons.first as AnyObject?) === (again.first as AnyObject?), "AX elements must retain stable identities")
        if let edgeButton = buttons.last as? NSAccessibilityElement {
            precondition(edgeButton.isAccessibilityElement() && edgeButton.isAccessibilityEnabled())
            precondition(edgeButton.accessibilityPerformPress(),"relationship detail action missing")
        }
        view.resetLayout()
        let pendingPoint = view.viewPoint(view.positions[view.data.nodes[0].id]!)
        view.mouseDown(with:mouse(.leftMouseDown,pendingPoint))
        view.mouseUp(with:mouse(.leftMouseUp,pendingPoint))
        precondition(view.layoutPending,"simple click must not cancel pending initial layout")
        wait(view); precondition(view.pinned.isEmpty)
        let after = model.memoryGraph.edges
        precondition(after.count == relations.count)
        for (index,edge) in after.enumerated() {
            precondition(edge.id == relations[index].0 && edge.inference?.fromQuote == relations[index].1 && edge.inference?.toQuote == relations[index].2,
                         "layout must never change business relations or source evidence")
        }
        // A late background result must not resurrect removed nodes.
        let detached = MemoryForceGraphView(frame:NSRect(x:0,y:0,width:800,height:500))
        detached.update(data:model.memoryGraph,selectedID:"",linkingFrom:"")
        detached.update(data:MemoryGraphData(),selectedID:"",linkingFrom:"")
        wait(detached)
        precondition(detached.positions.isEmpty && detached.data.nodes.isEmpty)
        print("PASS: native d3 graph zoom/pan/node drag/pins/reset/accessibility/edge details, background generation guard; business relations and both quotes unchanged")
    }
}
