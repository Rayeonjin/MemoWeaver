import Foundation
@main struct D3ForceLayoutSmoke {
    static func main() throws {
        let ids = ["note:요청", "note:완료", "note:</script>\";throw Error('injection');//"]
        let input = MemoryForceInput(nodes: ids.enumerated().map { MemoryForcePoint(id:$0.element,x:Double($0.offset)*10,y:0) },
            links:[MemoryForceEdge(source:ids[0],target:ids[1])],pinned:[])
        let points = try MemoryForceLayout.solve(input)
        precondition(Set(points.map(\.id)) == Set(ids), "IDs must be data, never script")
        for a in points { for b in points where a.id != b.id {
            precondition(hypot(a.x-b.x,a.y-b.y)>100, "collision force must separate labels")
        }}
        let pinned = MemoryForcePoint(id:ids[0],x:400,y:250)
        let fixed = try MemoryForceLayout.solve(.init(nodes:input.nodes,links:input.links,pinned:[pinned]))
        precondition(fixed.first { $0.id == pinned.id } == pinned, "drag position must remain fixed")
        let repeatPoints = try MemoryForceLayout.solve(input)
        precondition(repeatPoints == points, "same graph should have deterministic layout")
        let empty = try MemoryForceLayout.solve(.init(nodes:[],links:[],pinned:[]))
        precondition(empty.isEmpty)
        do {
            _ = try MemoryForceLayout.solve(.init(nodes:input.nodes,links:[.init(source:ids[0],target:"missing")],pinned:[]))
            preconditionFailure("dangling links accepted")
        } catch MemoryForceLayoutError.invalidInput {}
        let many = (0..<110).map { MemoryForcePoint(id:"n\($0)",x:Double($0%10)*160,y:Double($0/10)*160) }
        let edges = (1..<110).map { MemoryForceEdge(source:"n\($0-1)",target:"n\($0)") }
        let started = Date()
        let all = try MemoryForceLayout.solve(.init(nodes:many,links:edges,pinned:[]))
        precondition(all.count == 110 && all.allSatisfy { $0.x.isFinite && $0.y.isFinite })
        print("PERF: d3-force 110-node bounded solve \(Date().timeIntervalSince(started))s")
        let size = CGSize(width:800,height:500), anchor = CGPoint(x:123,y:234), world = CGPoint(x:40,y:-12)
        var camera = MemoryGraphViewport()
        let before = camera.worldPoint(anchor,size:size)
        camera.zoom(by:2,anchor:anchor,size:size)
        let after = camera.worldPoint(anchor,size:size)
        precondition(abs(before.x-after.x)<0.00001 && abs(before.y-after.y)<0.00001,"zoom must keep cursor anchor")
        precondition(camera.worldPoint(camera.viewPoint(world,size:size),size:size)==world)
        camera.zoom(by:100,anchor:anchor,size:size); precondition(camera.scale==3)
        camera.zoom(by:0.00001,anchor:anchor,size:size); precondition(camera.scale==0.2)
        camera.fit(points.map { CGPoint(x:$0.x,y:$0.y) },size:size)
        for point in points {
            let view = camera.viewPoint(CGPoint(x:point.x,y:point.y),size:size)
            precondition(view.x>=0 && view.x<=size.width && view.y>=0 && view.y<=size.height)
        }
        print("PASS: real bundled d3-force, collision, pins, deterministic finite positions, input safety, 110 nodes, cursor zoom/inverse/clamps/fit")
    }
}
