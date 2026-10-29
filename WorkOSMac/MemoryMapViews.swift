import SwiftUI

// Memory map is deliberately a native SwiftUI canvas; no CDN or web view is required.
struct MemoryMapScreen: View {
    @EnvironmentObject private var model: WorkOSModel
    @State private var selectedNodeID = ""
    @State private var linkingFrom = ""
    @State private var searchQuery = ""
    @State private var mapMode = "focus"

    private var selected: MemoryGraphNode? {
        model.memoryGraph.nodes.first { $0.id == selectedNodeID }
    }
    private var confirmed: MemoryLink? {
        guard !linkingFrom.isEmpty, !selectedNodeID.isEmpty else { return nil }
        return model.confirmedMemoryLinks.first { $0.id == MemoryLink(linkingFrom, selectedNodeID).id }
    }

    private var effectiveSelectedID: String {
        if model.memoryGraph.nodes.contains(where: { $0.id == selectedNodeID }) { return selectedNodeID }
        if let noteID = model.selectedNoteID {
            let id = "note:" + noteID
            if model.memoryGraph.nodes.contains(where: { $0.id == id }) { return id }
        }
        return model.memoryGraph.nodes.first?.id ?? ""
    }

    private var visibleGraph: MemoryGraphData {
        mapMode == "all" ? model.memoryGraph :
            MemoryGraphFocusCore.subset(model.memoryGraph, centerID: effectiveSelectedID)
    }

    private func refreshMap() {
        model.regenerateMemoryGraph(query: searchQuery)
        selectedNodeID = model.memoryGraph.nodes.first?.id ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 15) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("기억 지도").font(.title2.bold())
                    Text("노드: 메모·과거 자료 / 회색 점선: 의미 유사성 / 청록 점선: 근거 기반 AI 관계 / 실선: 직접 확정")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { refreshMap() } label: {
                    Label("새로고침", systemImage: "arrow.clockwise")
                }
                Button {
                    if model.isIndexingMemory { model.stopMemoryIndex() }
                    else { model.startMemoryIndex() }
                } label: {
                    Label(model.isIndexingMemory ? "색인 중단" : "의미 색인 실행", systemImage: "brain")
                }
                .disabled(!model.embeddingAvailable && !model.isIndexingMemory)
            }
            HStack(spacing: 9) {
                TextField("오래된 메모를 지도에서 찾기 (제목·본문 키워드)", text: $searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { refreshMap() }
                Button("지도에서 찾기") { refreshMap() }
                    .controlSize(.small)
            }
            HStack(spacing: 10) {
                Text("의미 연결 기준").font(.caption)
                Slider(value: Binding(get: { model.memoryThreshold },
                    set: { model.setMemoryThreshold($0) }), in: 0.45...0.88, step: 0.02)
                    .frame(width: 180)
                Text("\(Int(model.memoryThreshold * 100))%")
                    .font(.caption.monospacedDigit())
                Divider().frame(height: 18)
                Text("표시 \(model.memoryGraph.nodes.count)개 · 관계 \(model.memoryGraph.edges.count)개 · 색인 \(model.memoryGraph.indexedEntities)개 기록")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if !linkingFrom.isEmpty {
                    Button("연결 선택 취소") { linkingFrom = "" }
                        .controlSize(.small)
                }
            }
            HStack(spacing: 9) {
                Picker("지도 보기", selection: $mapMode) {
                    Text("선택 메모 중심").tag("focus")
                    Text("전체 연결").tag("all")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 235)
                if mapMode == "focus" {
                    Text("선택한 기록과 직접 연결된 최대 8개를 우선 표시합니다.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("큰 지도는 가로·세로 스크롤로 탐색할 수 있습니다.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if mapMode == "focus" {
                    Menu("중심 메모 선택") {
                        ForEach(model.memoryGraph.nodes.prefix(100)) { node in
                            Button(node.title) { selectedNodeID = node.id }
                        }
                    }
                    .controlSize(.small)
                }
            }
            if model.isIndexingMemory {
                ProgressView(value: model.memoryIndexProgress)
                    .progressViewStyle(.linear)
            }
            Text(model.memoryIndexStatus)
                .font(.caption2).foregroundStyle(.secondary)
                .lineLimit(2)
            Divider()
            if model.memoryGraph.nodes.isEmpty {
                ContentUnavailableView("표시할 메모가 없습니다", systemImage: "point.3.connected.trianglepath.dotted",
                    description: Text("노트를 만들고 AI 기억 분석을 사용하면 관련 기록들이 연결됩니다."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                MemoryGraphCanvas(data: visibleGraph, selectedID: effectiveSelectedID,
                                  linkingFrom: linkingFrom) { selectedNodeID = $0 }
            }
            Divider()
            if let selected {
                HStack(spacing: 12) {
                    Circle().fill(MemoryGraphCanvas.color(selected.cluster)).frame(width: 11, height: 11)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(selected.title).font(.subheadline.bold()).lineLimit(1)
                        Text(selected.subtitle).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Button("원문 열기") { model.openMemoryEntity(selected.id) }
                    if linkingFrom.isEmpty {
                        Button("이 기억과 연결 시작") { linkingFrom = selected.id }
                    } else if selected.id != linkingFrom {
                        if confirmed == nil {
                            Button("이 둘 연결 확정") {
                                model.addConfirmedMemoryLink(linkingFrom, selected.id)
                                linkingFrom = ""
                            }
                        } else {
                            Button("확정 연결 해제", role: .destructive) {
                                model.removeConfirmedMemoryLink(linkingFrom, selected.id)
                                linkingFrom = ""
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
                let inferred = model.sideInferredRelations(centerID: selected.id)
                if !inferred.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("원문으로 확인한 AI 업무 관계").font(.caption.bold())
                        ForEach(inferred.prefix(3)) { relation in
                            let other = relation.fromID == selected.id ? relation.toID : relation.fromID
                            Button("\(relation.typeLabel) · \(model.memoryTitle(other))") {
                                model.openMemoryEntity(other)
                            }.font(.caption).buttonStyle(.link)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Text("노드를 클릭하면 원문을 열거나 두 노트의 연결을 확정할 수 있습니다. 클러스터는 유사도 관계의 연결 성분입니다.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .onAppear {
            searchQuery = model.memoryGraphQuery
            model.regenerateMemoryGraph()
            selectedNodeID = effectiveSelectedID
        }
    }
}

struct MemoryGraphCanvas: View {
    let data: MemoryGraphData
    let selectedID: String
    let linkingFrom: String
    let onSelect: (String) -> Void

    private let nodeWidth: CGFloat = 148
    private let nodeHeight: CGFloat = 56

    static func color(_ group: Int) -> Color {
        let palette: [Color] = [.blue, .teal, .orange, .purple, .pink, .mint, .indigo, .brown]
        return palette[abs(group) % palette.count]
    }

    private var layout: (size: CGSize, coordinates: [String: CGPoint]) {
        if data.nodes.count <= 9 {
            let size = CGSize(width: 860, height: 560)
            guard let center = data.nodes.first else { return (size, [:]) }
            var coordinates: [String: CGPoint] = [center.id: CGPoint(x: 430, y: 280)]
            let neighbors = Array(data.nodes.dropFirst())
            for (index, node) in neighbors.enumerated() {
                let angle = (Double(index) / Double(max(1, neighbors.count))) * Double.pi * 2 - Double.pi / 2
                let radius: CGFloat = 220
                coordinates[node.id] = CGPoint(x: 430 + cos(angle) * radius,
                                                y: 280 + sin(angle) * radius)
            }
            return (size, coordinates)
        }
        let grouped = Dictionary(grouping: data.nodes, by: \.cluster)
        let clusters = grouped.keys.sorted { (grouped[$0]?.count ?? 0) > (grouped[$1]?.count ?? 0) }
        let columns = max(2, min(4, Int(ceil(sqrt(Double(max(1, clusters.count)))))))
        let cellsWide: CGFloat = 460
        let cellsHigh: CGFloat = 340
        let rows = max(1, Int(ceil(Double(clusters.count) / Double(columns))))
        let resultSize = CGSize(width: max(1040, CGFloat(columns) * cellsWide),
                                height: max(630, CGFloat(rows) * cellsHigh))
        var points: [String: CGPoint] = [:]
        for (groupIndex, key) in clusters.enumerated() {
            let center = CGPoint(x: (CGFloat(groupIndex % columns) + 0.5) * cellsWide,
                                 y: (CGFloat(groupIndex / columns) + 0.5) * cellsHigh)
            let members = (grouped[key] ?? []).sorted { $0.title < $1.title }
            if members.count == 1 { points[members[0].id] = center; continue }
            // Multiple rings keep labels clickable even in a larger cluster.
            let perRing = 9
            for (offset, node) in members.enumerated() {
                let ring = offset / perRing
                let index = offset % perRing
                let count = min(perRing, members.count - ring * perRing)
                let angle = (Double(index) / Double(count)) * Double.pi * 2 - Double.pi / 2
                let radius = CGFloat(115 + ring * 116)
                points[node.id] = CGPoint(x: center.x + cos(angle) * radius,
                                          y: center.y + sin(angle) * radius)
            }
        }
        return (resultSize, points)
    }

    var body: some View {
        let geometry = layout
        ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    for edge in data.edges {
                        guard let a = geometry.coordinates[edge.first],
                              let b = geometry.coordinates[edge.second] else { continue }
                        var path = Path()
                        path.move(to: a)
                        path.addLine(to: b)
                        let hasInference = !edge.inferredType.isEmpty
                        let style = StrokeStyle(lineWidth: edge.confirmed ? 2.6 : (hasInference ? 2.2 : 1.4),
                                                lineCap: .round,
                                                dash: edge.confirmed ? [] : (hasInference ? [3, 3] : [5, 5]))
                        context.stroke(path, with: .color(edge.confirmed ? Color.accentColor :
                            (hasInference ? Color.teal.opacity(0.95) : .secondary.opacity(0.57))), style: style)
                    }
                }
                ForEach(data.nodes) { node in
                    let selected = node.id == selectedID
                    Button { onSelect(node.id) } label: {
                        VStack(spacing: 4) {
                            Label(node.title, systemImage: node.kind == "archive" ? "archivebox" : "doc.text")
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                            Text(node.kind == "archive" ? "TXT 자료" : node.subtitle)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(width: nodeWidth, height: nodeHeight)
                        .background(RoundedRectangle(cornerRadius: 11)
                            .fill(Self.color(node.cluster).opacity(selected ? 0.32 : 0.20)))
                        .overlay(RoundedRectangle(cornerRadius: 11)
                            .stroke(selected ? Color.accentColor : Self.color(node.cluster).opacity(0.60),
                                    lineWidth: selected ? 2.5 : 1.2))
                        .overlay(alignment: .topTrailing) {
                            if node.id == linkingFrom {
                                Image(systemName: "link.circle.fill")
                                    .foregroundStyle(.blue)
                                    .padding(3)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .position(geometry.coordinates[node.id] ?? .zero)
                    .memoTooltip(node.title, when: node.title.count > 26)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct MemoryAssistPanel: View {
    @EnvironmentObject private var model: WorkOSModel
    let noteID: String
    @Binding var typeID: String
    @Binding var bookID: String

    var body: some View {
        let neighbors = model.memoryRelated(noteID: noteID)
        let confirmed = model.confirmedLinks(for: "note:" + noteID)
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Label("연관 기억", systemImage: "brain.head.profile").font(.caption.bold())
                Text("bge-m3 의미 검색 · 변경은 직접 확정").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                if model.embeddingAvailable && !model.isIndexingMemory {
                    Button("색인 갱신") { model.startMemoryIndex() }
                        .controlSize(.mini)
                }
            }
            if neighbors.isEmpty {
                Text(model.memoryVectors.isEmpty ? "색인이 아직 없습니다. Ollama 연결 후 '색인 갱신'을 눌러 주세요." :
                    "현재 기준에서 의미상 가까운 기록이 없습니다. 기억 지도에서 유사도 기준을 조절할 수 있습니다.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            ForEach(neighbors.prefix(5)) { neighbor in
                HStack(spacing: 7) {
                    Button {
                        model.openMemoryNeighbor(neighbor)
                    } label: {
                        Label(neighbor.title, systemImage: neighbor.kind == "archive" ? "archivebox" : "doc.text")
                            .lineLimit(1)
                    }
                    .buttonStyle(.link)
                    Text(String(format: "유사도 %.2f", neighbor.similarity))
                        .memoTooltip("코사인 유사도입니다. 정답 확률이나 연관 관계의 확실성을 뜻하지 않습니다.")
                        .foregroundStyle(.secondary)
                    if neighbor.kind == "archive" {
                        Text("\(neighbor.fromLine)~\(neighbor.toLine)행")
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 0)
                    let already = confirmed.contains { $0.id == MemoryLink("note:" + noteID, neighbor.id).id }
                    if already {
                        Text("확정됨").foregroundStyle(.green)
                    } else {
                        Button("연결") { model.addConfirmedMemoryLink("note:" + noteID, neighbor.id) }
                            .controlSize(.mini)
                    }
                }
                .font(.caption)
            }
            let typeRecommendations = model.recommendedTypes(noteID: noteID, current: typeID)
            let bookRecommendations = model.recommendedBooks(noteID: noteID, current: bookID)
            if !typeRecommendations.isEmpty || !bookRecommendations.isEmpty {
                Divider()
                Text("기존 메모를 근거로 한 분류 추천").font(.caption.bold())
                HStack(spacing: 13) {
                    ForEach(typeRecommendations.prefix(1)) { advice in
                        Button("종류: \(advice.name) 적용") { typeID = advice.id }
                            .memoTooltip("추천 근거: \(advice.evidence)")
                    }
                    ForEach(bookRecommendations.prefix(1)) { advice in
                        Button("노트북: \(advice.name) 적용") { bookID = advice.id }
                            .memoTooltip("추천 근거: \(advice.evidence)")
                    }
                    Spacer()
                }
                .font(.caption)
                .controlSize(.small)
            }
            if !confirmed.isEmpty {
                Divider()
                Text("내가 확정한 양방향 연결").font(.caption.bold())
                ForEach(confirmed) { link in
                    let other = link.first == "note:" + noteID ? link.second : link.first
                    HStack(spacing: 8) {
                        Button(model.memoryTitle(other)) { model.openMemoryEntity(other) }
                            .buttonStyle(.link)
                            .lineLimit(1)
                        Spacer()
                        Button("연결 해제") {
                            model.removeConfirmedMemoryLink("note:" + noteID, other)
                        }
                        .controlSize(.mini)
                    }.font(.caption)
                }
            }
        }
    }
}
