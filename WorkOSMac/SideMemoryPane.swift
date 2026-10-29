import SwiftUI

/// An ego-network for the active Markdown editor. No global 110-node tangle:
/// one source/virtual segment plus at most five related records. Opening the
/// tab loads existing local cache; it never submits text to Ollama by itself.
struct SideMemoryPane: View {
    @EnvironmentObject private var model: WorkOSModel
    let noteID: String
    let caretLine: Int

    private var centerID: String {
        model.sideMemoryCenter(noteID: noteID, caretLine: caretLine)
    }

    private var related: [MemoryNeighbor] {
        model.sideMemoryNeighbors(centerID: centerID)
    }

    private var sourceCaption: String {
        if centerID.hasPrefix("virtual:") {
            let item = model.virtualMemories.first { "virtual:" + $0.id == centerID }
            return item.map { "가상 메모 · 원문 \($0.lineLabel)" } ?? "가상 메모"
        }
        if model.staleVirtualSources.contains("note:" + noteID) {
            return "원문이 변경되어 가상 메모 재분석 필요"
        }
        return "현재 메모 전체"
    }

    private var inferredIDs: Set<String> {
        Set(model.sideInferredRelations(centerID: centerID).map {
            $0.fromID == centerID ? $0.toID : $0.fromID
        })
    }

    private var confirmedIDs: Set<String> {
        Set(model.confirmedLinks(for: centerID).compactMap { link in
            if link.first == centerID { return link.second }
            if link.second == centerID { return link.first }
            return nil
        })
    }

    var body: some View {
        let focus = centerID
        let neighbors = related
        let confirmed = confirmedIDs
        let inferred = inferredIDs
        let relationTypes = Dictionary(uniqueKeysWithValues:
            model.sideInferredRelations(centerID: focus).map {
                ($0.fromID == focus ? $0.toID : $0.fromID, $0.typeLabel)
            })
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    Label("현재 메모의 기억", systemImage: "brain.head.profile")
                        .font(.subheadline.bold())
                    Spacer(minLength: 4)
                    Button("전체 지도") { model.selectedPage = .memory }
                        .controlSize(.small)
                }
                Text(sourceCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if model.isIndexingMemory {
                    ProgressView(value: model.memoryIndexProgress)
                        .progressViewStyle(.linear)
                    Text(model.memoryIndexStatus).font(.caption2).foregroundStyle(.secondary)
                }
                if neighbors.isEmpty {
                    ContentUnavailableView("연결된 기억이 없습니다",
                        systemImage: "point.3.connected.trianglepath.dotted",
                        description: Text(model.memoryVectors.isEmpty
                            ? "기억 지도에서 bge-m3 의미 색인을 실행하면 과거 기록과의 관련성이 표시됩니다."
                            : "현재 구간에서 기준을 만족하는 관계가 없습니다. 전체 지도에서 연결 기준을 조정할 수 있습니다."))
                    .frame(minHeight: 160)
                } else {
                    SideMemoryEgoGraph(centerTitle: model.memoryTitle(focus),
                                       neighbors: neighbors, confirmedIDs: confirmed,
                                       inferredIDs: inferred) { id in
                        if let selected = neighbors.first(where: { $0.id == id }) {
                            model.openMemoryNeighbor(selected)
                        }
                    }
                    .accessibilityLabel("현재 기록과 관련 기억 \(neighbors.count)개를 연결한 그래프")
                    Divider()
                    HStack {
                        Text("관련 기록").font(.subheadline.bold())
                        Spacer()
                        Text("최대 5개").font(.caption2).foregroundStyle(.secondary)
                    }
                    ForEach(neighbors) { neighbor in
                        Button { model.openMemoryNeighbor(neighbor) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: neighbor.kind == "virtual" ? "text.book.closed" :
                                          (neighbor.kind == "archive" ? "archivebox" : "doc.text"))
                                        .foregroundStyle(.secondary)
                                    Text(neighbor.title).font(.caption.bold()).lineLimit(2)
                                    Spacer(minLength: 0)
                                    Image(systemName: "arrow.up.right").font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                HStack(spacing: 5) {
                                    if confirmed.contains(neighbor.id) {
                                        Label("확정 연결", systemImage: "link")
                                    } else if inferred.contains(neighbor.id) {
                                        Text("AI 추론 · " + (relationTypes[neighbor.id] ?? "원문 근거 확인"))
                                    } else {
                                        Text(String(format: "유사도 %.2f", neighbor.similarity))
                                    }
                                    if neighbor.fromLine > 0 {
                                        Text("· \(neighbor.fromLine)~\(neighbor.toLine)행")
                                    }
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color.secondary.opacity(0.065), in: RoundedRectangle(cornerRadius: 9))
                        }
                        .buttonStyle(.plain)
                        .memoTooltip("원본 메모 또는 가상 메모의 원래 위치 열기")
                    }
                    Text("유사도는 문맥의 코사인 유사도이며 관련성의 확률이 아닙니다.")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                SideInferredRelationSection(centerID: centerID)
                SideMemoryTimelineSection(centerID: centerID)
                Divider()
                HStack(spacing: 9) {
                    if model.embeddingAvailable {
                        Button { model.startMemoryIndex() } label: {
                            Label("의미 색인 갱신", systemImage: "arrow.clockwise")
                        }
                        .disabled(model.isIndexingMemory)
                    }
                    if !model.aiConnected {
                        Button { Task { await model.checkAI() } } label: {
                            Label("Ollama 연결", systemImage: "bolt.horizontal.circle")
                        }
                        .disabled(model.isCheckingAI)
                    }
                    if model.isInferringMemory {
                        Button { model.stopRelationAnalysis() } label: {
                            Label("관계 분석 중단", systemImage: "stop.circle")
                        }
                    } else {
                        Button { model.startRelationAnalysis(centerID: centerID) } label: {
                            Label("AI 관계 분석", systemImage: "sparkles")
                        }
                        .disabled(!model.aiConnected || model.isIndexingMemory)
                        .memoTooltip("로컬 채팅 모델이 사건·판단을 추출하고 원문에서 인용문을 검증합니다.")
                    }
                    Spacer(minLength: 0)
                }
                .controlSize(.small)
                if model.isInferringMemory {
                    ProgressView(value: model.inferenceProgress).progressViewStyle(.linear)
                }
                Text(model.inferenceStatus).font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(3)
                Text("메모 작성 중 AI를 자동 호출하지 않습니다. 마지막으로 저장된 색인 결과를 표시합니다.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { model.loadMemoryCache() }
    }
}

private struct SideMemoryEgoGraph: View {
    let centerTitle: String
    let neighbors: [MemoryNeighbor]
    let confirmedIDs: Set<String>
    let inferredIDs: Set<String>
    let open: (String) -> Void

    private var height: CGFloat { 116 + CGFloat((neighbors.count + 1) / 2) * 66 }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let cardWidth = max(70, min(128, width * 0.43))
            ZStack {
                Canvas { context, size in
                    for (index, neighbor) in neighbors.enumerated() {
                        let endpoint = CGPoint(x: size.width * (index.isMultiple(of: 2) ? 0.26 : 0.74),
                                               y: 125 + CGFloat(index / 2) * 66)
                        var path = Path()
                        path.move(to: CGPoint(x: size.width / 2, y: 57))
                        path.addLine(to: endpoint)
                        let isConfirmed = confirmedIDs.contains(neighbor.id)
                        let isInferred = inferredIDs.contains(neighbor.id)
                        context.stroke(path, with: .color(isConfirmed ? Color.accentColor.opacity(0.70) :
                            (isInferred ? Color.teal.opacity(0.83) : .secondary.opacity(0.32))),
                            style: StrokeStyle(lineWidth: isConfirmed ? 2 : (isInferred ? 1.9 : 1.2),
                                               dash: isConfirmed ? [] : [4, 4]))
                    }
                }
                Text(centerTitle)
                    .font(.system(size: 12, weight: .bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: min(176, width - 18), height: 49)
                    .background(Color.accentColor.opacity(0.20), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor, lineWidth: 1.8))
                    .position(x: width / 2, y: 31)
                ForEach(neighbors.indices, id: \.self) { index in
                    let item = neighbors[index]
                    Button { open(item.id) } label: {
                        Text(item.title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(width: cardWidth, height: 48)
                            .background(Color.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9)
                                .stroke(confirmedIDs.contains(item.id) ? Color.accentColor.opacity(0.75) :
                                        (inferredIDs.contains(item.id) ? Color.teal : Color.secondary.opacity(0.35)), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .memoTooltip(item.title, when: item.title.count > 18)
                    .position(x: width * (index.isMultiple(of: 2) ? 0.26 : 0.74),
                              y: 125 + CGFloat(index / 2) * 66)
                }
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    }
}


// Evidence and AI's interpretation are displayed separately. An exact quote
// match is not proof of a causal claim; all AI relations remain labelled AI.
private struct SideInferredRelationSection: View {
    @EnvironmentObject private var model: WorkOSModel
    let centerID: String

    var body: some View {
        let relationships = model.sideInferredRelations(centerID: centerID)
        let facts = model.factsForSideMemory(centerID)
        if !relationships.isEmpty || !facts.isEmpty {
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Label("업무 맥락 · AI 추론", systemImage: "sparkles")
                    .font(.subheadline.bold())
                Text("인용문 존재 여부를 검증한 분석 결과입니다. 실제 인과관계나 동일 사건 여부는 직접 확인해 주세요.")
                    .font(.caption2).foregroundStyle(.secondary)
                ForEach(Array(relationships.prefix(5))) { relation in
                    let other = relation.fromID == centerID ? relation.toID : relation.fromID
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(relation.summary).font(.caption)
                            Text("현재 원문 인용").font(.caption2.bold())
                            Text(relation.fromID == centerID ? relation.fromQuote : relation.toQuote)
                                .font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
                            Text("관련 메모 인용").font(.caption2.bold())
                            Text(relation.fromID == centerID ? relation.toQuote : relation.fromQuote)
                                .font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
                            HStack(spacing: 12) {
                                Button("관련 원문 읽기") { model.openMemoryEntity(other) }
                                    .font(.caption).buttonStyle(.link)
                                Button("유용한 관계") {
                                    model.setRelationReview(relation, decision: "helpful")
                                }.font(.caption).buttonStyle(.link)
                                Button("무관함 · 숨기기") {
                                    model.setRelationReview(relation, decision: "irrelevant")
                                }.font(.caption).buttonStyle(.link)
                            }
                        }
                        .padding(.top, 5)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(relation.typeLabel + " · " + model.memoryTitle(other))
                                .font(.caption.bold()).lineLimit(2)
                            Text("AI 추론 · 양쪽 원문 인용 확인")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(8)
                    .background(Color.teal.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                }
                if !facts.isEmpty {
                    DisclosureGroup("현재 기록에서 추출한 사건·판단 (\(facts.count))") {
                        ForEach(facts) { fact in
                            VStack(alignment: .leading, spacing: 3) {
                                Text((MemoryRelationCore.factLabels[fact.kind] ?? "기록") + " · " + fact.summary)
                                    .font(.caption.bold())
                                Text("원문: " + fact.quote)
                                    .font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
                            }.padding(.vertical, 3)
                        }
                    }.font(.caption)
                }
            }
        }
    }
}


// Follow-up paths are composed ONLY of checked AI relations, not raw
// embedding scores. A trail is a hypothesis whose cited originals can be read.
private struct SideMemoryTimelineSection: View {
    @EnvironmentObject private var model: WorkOSModel
    let centerID: String

    var body: some View {
        let paths = model.memoryTimeline(for: centerID)
        let notFound = model.memoryWithoutKnownFollowUp(for: centerID)
        let hidden = model.inferredMemoryRelations.filter { relation in
            relation.hasRelationship && model.relationIsHidden(relation) &&
            (relation.fromID == centerID || relation.toID == centerID)
        }
        if !paths.isEmpty || !notFound.isEmpty || !hidden.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                if !paths.isEmpty {
                    Label("업무 흐름 · 근거 있는 연결", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.subheadline.bold())
                    Text("AI가 제안한 기록 간 경로이며 사건 발생 순서를 확정하지는 않습니다.")
                        .font(.caption2).foregroundStyle(.secondary)
                    ForEach(paths) { path in
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(path.relationships) { link in
                                HStack(alignment: .firstTextBaseline, spacing: 5) {
                                    Button(model.memoryTitle(link.fromID)) {
                                        model.openMemoryEntity(link.fromID)
                                    }.buttonStyle(.link)
                                    Text("→ " + link.typeLabel + " →")
                                        .foregroundStyle(.secondary)
                                    Button(model.memoryTitle(link.toID)) {
                                        model.openMemoryEntity(link.toID)
                                    }.buttonStyle(.link)
                                }
                                .font(.caption)
                                Text(link.summary)
                                    .font(.caption2).foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                        }
                        .padding(9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                if !notFound.isEmpty {
                    DisclosureGroup("후속 기록을 찾지 못한 문제·질문 (\(notFound.count))") {
                        ForEach(notFound) { fact in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(fact.summary).font(.caption.bold())
                                Text("출처: " + fact.quote).font(.caption2)
                                Text("미해결로 확정된 것은 아닙니다. 현재 색인에서 후속 연결을 발견하지 못했습니다.")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }.padding(.vertical, 4)
                        }
                    }
                    .font(.caption)
                }
                if !hidden.isEmpty {
                    DisclosureGroup("숨긴 관계 다시 표시 (\(hidden.count))") {
                        ForEach(hidden) { relation in
                            HStack {
                                Text(relation.typeLabel + " · " + model.memoryTitle(
                                    relation.fromID == centerID ? relation.toID : relation.fromID))
                                    .font(.caption).lineLimit(2)
                                Spacer()
                                Button("복원") { model.clearRelationReview(relation) }
                                    .controlSize(.small)
                            }
                        }
                    }.font(.caption)
                }
            }
        }
    }
}
