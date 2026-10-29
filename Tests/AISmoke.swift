import Foundation

// Local-only demo diagnostic. No private WorkOS notes are opened or transmitted.
// A synthetic test is NOT a measurement of your real corpus retrieval accuracy.
@main
struct AISmoke {
    static func main() async {
        let service = OllamaService()
        let started = Date()
        do {
            let tags = try await service.models()
            print("[AI test] Ollama /api/tags OK, models: \(tags.map(\.name).joined(separator: ", "))")
            guard tags.contains(where: { $0.name == "bge-m3" || $0.name == "bge-m3:latest" }) else {
                print("FAIL: bge-m3 not installed/available in Ollama")
                exit(2)
            }
            let texts = [
                "배포 이후 API 처리 지연이 발생하여 서버 타임아웃을 점검했다.",
                "서버를 새로 배포한 뒤 요청 응답 속도가 느려졌으며 제한 시간을 확인했다.",
                "점심 회식 장소를 예약하고 다음주 팀원 참석 여부를 확인했다."
            ]
            let embeddingStart = Date()
            let vectors = try await service.embed(texts)
            let embeddingSeconds = Date().timeIntervalSince(embeddingStart)
            func similarity(_ a: [Double], _ b: [Double]) -> Double {
                guard a.count == b.count, !a.isEmpty else { return 0 }
                let dot = zip(a,b).reduce(0.0) { $0 + $1.0 * $1.1 }
                let aa = sqrt(a.reduce(0.0) { $0 + $1 * $1 })
                let bb = sqrt(b.reduce(0.0) { $0 + $1 * $1 })
                return aa > 0 && bb > 0 ? dot / (aa*bb) : 0
            }
            let related = similarity(vectors[0], vectors[1])
            let unrelated = similarity(vectors[0], vectors[2])
            print(String(format: "[AI test] bge-m3: %d dimensions, 3 sentences %.2fs", vectors[0].count, embeddingSeconds))
            print(String(format: "[AI test] similarity: relevant %.3f, unrelated %.3f (not calibrated confidence)", related, unrelated))
            print("[AI test] semantic ranking sanity check: \(related > unrelated ? "PASS" : "CHECK manually")")
            print("[AI test] tags + embedding test completed in \(String(format: "%.2f", Date().timeIntervalSince(started)))s")
            guard CommandLine.arguments.contains("--chat") else {
                print("[AI test] Chat skipped; run ./test-ai.sh --chat to test one synthetic grounded question")
                return
            }
            guard let chosen = tags.first(where: { $0.name == "qwen3.5:4b" }) ??
                    tags.first(where: { $0.supportsChat }) else {
                print("[AI test] No installed chat model available")
                return
            }
            let source = MemorySource(id: "fixture1", kind: "note", sourceID: "fixture1",
                title: "가상 점검 기록", subtitle: "2026-10-01", text: "장애 원인은 DB 연결 풀 고갈이며, 연결 풀 크기를 조정하여 복구했다.",
                fromLine: 0, toLine: 0, score: 100)
            let chatStart = Date()
            let reply = try await service.answer(model: chosen.name,
                question: "가상 점검 기록에서 장애 원인은 무엇이고 어떻게 복구했나?", sources: [source])
            print("[AI test] chat model \(chosen.name), latency \(String(format: "%.2f", Date().timeIntervalSince(chatStart)))s")
            print("[AI test] response: \(String(reply.prefix(600)))")
            print("[AI test] citations present: \(reply.contains("[1]") ? "YES" : "NO (review required)")")
            print("[AI test] source fact mentioned: \(reply.contains("연결 풀") || reply.contains("커넥션 풀") ? "YES" : "CHECK manually")")
        } catch {
            print("[AI test] ERROR: \(error.localizedDescription)")
            exit(1)
        }
    }
}
