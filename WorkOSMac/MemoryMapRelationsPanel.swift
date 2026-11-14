import SwiftUI

// Uses the same current, evidence-checked relation snapshot as the map. No
// Ollama call, note mutation, or guessed quotation when inspecting an edge.
struct MemoryMapRelationsPanel: View {
    @EnvironmentObject private var model: WorkOSModel
    let graph: MemoryGraphData
    let centerID: String
    @Binding var selectedEdgeID: String

    private var incident: [MemoryGraphEdge] {
        graph.edges.filter { $0.first == centerID || $0.second == centerID }
            .sorted { a, b in
                if a.confirmed != b.confirmed { return a.confirmed }
                return a.id < b.id
            }
    }
    private var selected: MemoryGraphEdge? {
        graph.edges.first { $0.id == selectedEdgeID } ?? incident.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if graph.edges.isEmpty {
                Text("표시할 업무 관계가 없습니다. 선택 기록의 업무 관계를 분석하거나 직접 연결해 주세요. 유사성만 있는 기록은 선으로 표시하지 않습니다.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(incident) { edge in
                            let other = edge.first == centerID ? edge.second : edge.first
                            Button { selectedEdgeID = edge.id } label: {
                                HStack {
                                    Image(systemName: edge.confirmed ? "link" : "sparkles")
                                    Text((edge.confirmed ? ReferencePanelCore.manualLabel(edge.manualKind) : edge.inferredType)
                                         + " · " + model.memoryTitle(other))
                                        .lineLimit(2)
                                    Spacer()
                                    if edge.id == selected?.id { Image(systemName: "chevron.down") }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(.plain).font(.caption.weight(.medium))
                        }
                        if let selected {
                            MemoryMapRelationDetail(edge: selected)
                                .id(selected.id)
                        } else if incident.isEmpty {
                            Text("이 기록에는 아직 업무 관계가 없습니다. 관계 분석을 실행하거나 지도에서 다른 관계 이름을 선택하세요.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(8)
                }
                .frame(maxHeight: 230)
                .background(Color.teal.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            }
            let hidden = model.inferredMemoryRelations.filter {
                $0.hasRelationship && ($0.fromID == centerID || $0.toID == centerID) && model.relationIsHidden($0)
            }
            if !hidden.isEmpty {
                DisclosureGroup("숨긴 AI 관계 (\(hidden.count))") {
                    ForEach(Array(hidden.prefix(20))) { relation in
                        HStack {
                            Text(relation.typeLabel + " · " + model.memoryTitle(
                                relation.fromID == centerID ? relation.toID : relation.fromID))
                                .lineLimit(1)
                            Spacer()
                            Button("복원") { model.clearRelationReview(relation) }.buttonStyle(.link)
                        }.font(.caption)
                    }
                }.font(.caption)
            }
        }
    }
}

struct MemoryMapRelationDetail: View {
    @EnvironmentObject private var model: WorkOSModel
    let edge: MemoryGraphEdge

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if edge.confirmed {
                Text("사용자 직접 연결 · " + ReferencePanelCore.manualLabel(edge.manualKind))
                    .font(.caption.bold())
                Text(edge.manualMemo.isEmpty ? "연결 이유가 기록되지 않은 직접 연결입니다." : edge.manualMemo)
                    .font(.caption).textSelection(.enabled)
            }
            if let relation = edge.inference {
                Divider()
                Text("AI 추론 · " + relation.typeLabel).font(.caption.bold())
                let connector = ["same_case", "related_case"].contains(relation.relationType) ? " ↔ " : " → "
                Text(model.memoryTitle(relation.fromID) + connector + model.memoryTitle(relation.toID))
                    .font(.caption.weight(.medium)).textSelection(.enabled)
                Text(relation.summary).font(.caption).textSelection(.enabled)
                evidence(id: relation.fromID, quote: relation.fromQuote)
                evidence(id: relation.toID, quote: relation.toQuote)
                Text("인용문이 현재 원문에 있는지 확인한 AI 해석입니다. 업무 관계의 타당성은 직접 확인해 주세요.")
                    .font(.caption2).foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Button("유용한 관계") { model.setRelationReview(relation, decision: "helpful") }
                    Button("AI 관계 무관함 · 숨기기") { model.setRelationReview(relation, decision: "irrelevant") }
                }.font(.caption).buttonStyle(.link)
                if edge.confirmed {
                    Text("AI 관계를 숨겨도 사용자 직접 연결은 유지됩니다.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            } else if edge.confirmed {
                Text("이 연결에 검증된 AI 원문 인용은 없습니다. 양쪽 원문을 직접 확인할 수 있습니다.")
                    .font(.caption2).foregroundStyle(.secondary)
                HStack {
                    Button("첫 번째 원문 열기") { model.openMemoryEntity(edge.first) }
                    Button("두 번째 원문 열기") { model.openMemoryEntity(edge.second) }
                }.font(.caption).buttonStyle(.link)
            }
        }
        .accessibilityIdentifier("memory.relation.detail")
    }

    private func evidence(id: String, quote: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("원문 근거 · " + model.memoryTitle(id)).font(.caption2.bold())
                Button("원문 열기") { model.openMemoryEvidence(id, quote: quote) }
                    .font(.caption).buttonStyle(.link)
            }
            Text(quote).font(.caption).textSelection(.enabled)
        }
    }
}
