import Foundation

// Minimal mock model verifies the real Foundation-only focus algorithm,
// independent of SwiftUI, AppKit, Ollama, and user files.
struct MemoryGraphNode: Identifiable { let id: String; let title: String }
struct MemoryGraphEdge {
    let first: String
    let second: String
    let strength: Double
    let confirmed: Bool
}
struct MemoryGraphData {
    var nodes: [MemoryGraphNode] = []
    var edges: [MemoryGraphEdge] = []
    var indexedEntities: Int = 0
}
@main struct MemoryGraphFocusV0946Smoke {
    static func main() {
        let nodes = (0...12).map { MemoryGraphNode(id: "n\($0)", title: "메모 \($0)") }
        let edges = (1...12).map {
            MemoryGraphEdge(first: "n0", second: "n\($0)",
                            strength: 1.0 - Double($0) / 100.0,
                            confirmed: $0 == 10)
        }
        let graph = MemoryGraphData(nodes: nodes, edges: edges, indexedEntities: 35)
        let focused = MemoryGraphFocusCore.subset(graph, centerID: "n0", maxNeighbors: 4)
        precondition(focused.nodes.count == 5)
        precondition(focused.edges.count == 4)
        precondition(focused.edges.first?.second == "n10", "Manually confirmed relation first")
        precondition(focused.nodes.first?.id == "n0")
        precondition(focused.indexedEntities == 35)
        let lone = MemoryGraphFocusCore.subset(graph, centerID: "n9", maxNeighbors: 3)
        precondition(lone.nodes.count == 2)
        precondition(lone.edges.count == 1)
        precondition(MemoryGraphFocusCore.subset(MemoryGraphData(), centerID: "nothing").nodes.isEmpty)
        print("PASS v0.9.46 focus: confirmed ordering, degree cap, missing/leaf targets, original index count")
    }
}
