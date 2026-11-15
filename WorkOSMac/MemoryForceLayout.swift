import Foundation
import JavaScriptCore

struct MemoryForcePoint: Codable, Equatable {
    let id: String
    var x: Double
    var y: Double
}
struct MemoryForceEdge: Codable { let source: String; let target: String }
struct MemoryForceInput: Codable {
    let nodes: [MemoryForcePoint]
    let links: [MemoryForceEdge]
    let pinned: [MemoryForcePoint]
}
enum MemoryForceLayoutError: Error { case missingRuntime, invalidInput, scriptFailure, invalidOutput }

// A new context is owned by one background job. No web view, timers, network,
// database, note bodies, or AI is exposed. Only IDs, edges and coordinates enter.
enum MemoryForceLayout {
    static let queue = DispatchQueue(label: "MemoWeaver.force-layout", qos: .userInitiated)
    static func runtimeURL() -> URL? {
        if let bundled = Bundle.main.url(forResource: "memory-force-layout", withExtension: "js") { return bundled }
        // Command-line regression fixtures only; installed apps require their bundle.
        guard Bundle.main.bundleIdentifier == nil else { return nil }
        return URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Resources/memory-force-layout.js")
    }
    static func solve(_ input: MemoryForceInput, runtimeURL: URL? = MemoryForceLayout.runtimeURL()) throws -> [MemoryForcePoint] {
        let ids = Set(input.nodes.map(\.id))
        guard input.nodes.count <= 110, ids.count == input.nodes.count,
              input.links.count <= 12000,
              input.nodes.allSatisfy({ $0.x.isFinite && $0.y.isFinite }),
              input.pinned.allSatisfy({ ids.contains($0.id) && $0.x.isFinite && $0.y.isFinite }),
              input.links.allSatisfy({ ids.contains($0.source) && ids.contains($0.target) && $0.source != $0.target })
        else { throw MemoryForceLayoutError.invalidInput }
        guard let runtimeURL, let source = try? String(contentsOf: runtimeURL, encoding: .utf8),
              let context = JSContext() else { throw MemoryForceLayoutError.missingRuntime }
        var failure = false
        context.exceptionHandler = { _, _ in failure = true }
        context.evaluateScript(source)
        guard !failure else { throw MemoryForceLayoutError.scriptFailure }
        let json = String(decoding: try JSONEncoder().encode(input), as: UTF8.self)
        guard let encoded = context.objectForKeyedSubscript("memoWeaverForceSolve")?
                .call(withArguments: [json])?.toString(), !failure,
              let data = encoded.data(using: .utf8), data.count <= 100_000,
              let points = try? JSONDecoder().decode([MemoryForcePoint].self, from: data),
              points.count == input.nodes.count, Set(points.map(\.id)) == ids,
              points.allSatisfy({ $0.x.isFinite && $0.y.isFinite && abs($0.x) < 1_000_000 && abs($0.y) < 1_000_000 })
        else { throw MemoryForceLayoutError.invalidOutput }
        return points
    }
}

// Independent viewport math: rendering, hit testing and drag all use this same
// transform, including cursor-anchored zoom and bounded fit-to-content.
struct MemoryGraphViewport {
    private(set) var scale: CGFloat = 1
    var translation: CGPoint = .zero
    func viewPoint(_ world: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2 + translation.x + world.x * scale,
                y: size.height / 2 + translation.y + world.y * scale)
    }
    func worldPoint(_ point: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(x: (point.x - size.width / 2 - translation.x) / scale,
                y: (point.y - size.height / 2 - translation.y) / scale)
    }
    mutating func zoom(by factor: CGFloat, anchor: CGPoint, size: CGSize) {
        guard factor.isFinite, factor > 0 else { return }
        let world = worldPoint(anchor, size: size)
        scale = max(0.2, min(3, scale * factor))
        translation = CGPoint(x: anchor.x - size.width / 2 - world.x * scale,
                              y: anchor.y - size.height / 2 - world.y * scale)
    }
    mutating func fit(_ points: [CGPoint], size: CGSize) {
        guard size.width > 0, size.height > 0, !points.isEmpty else { return }
        let xs = points.map(\.x), ys = points.map(\.y)
        let minX = xs.min()! - 90, maxX = xs.max()! + 90
        let minY = ys.min()! - 45, maxY = ys.max()! + 60
        scale = max(0.2, min(1.4, min(max(1,size.width - 40) / (maxX - minX),
                                    max(1,size.height - 40) / (maxY - minY))))
        translation = CGPoint(x: -(minX + maxX) / 2 * scale, y: -(minY + maxY) / 2 * scale)
    }
}
