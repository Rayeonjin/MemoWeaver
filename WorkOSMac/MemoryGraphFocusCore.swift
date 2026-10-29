import Foundation

// Focused ego-network for legible note exploration. No AI call, no mutation,
// no additional note read, and no fabricated edge or relationship.
enum MemoryGraphFocusCore {
    static func subset(_ graph: MemoryGraphData, centerID: String, maxNeighbors: Int = 8) -> MemoryGraphData {
        guard let center = graph.nodes.first(where: { $0.id == centerID }) else {
            return MemoryGraphData(nodes: Array(graph.nodes.prefix(1)), edges: [],
                                   indexedEntities: graph.indexedEntities)
        }
        let connected = graph.edges.filter { $0.first == centerID || $0.second == centerID }
            .sorted { a, b in
                if a.confirmed != b.confirmed { return a.confirmed }
                return a.strength > b.strength
            }
        let neighbors = Array(connected.prefix(max(0, maxNeighbors)))
        let ids = Set(neighbors.flatMap { [$0.first, $0.second] })
        let nodes = [center] + graph.nodes.filter { ids.contains($0.id) && $0.id != centerID }
        return MemoryGraphData(nodes: nodes, edges: neighbors, indexedEntities: graph.indexedEntities)
    }
}
