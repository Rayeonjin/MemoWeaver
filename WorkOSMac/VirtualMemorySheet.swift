import SwiftUI

// Deliberately separated from ordinary editing. Analyzing never mutates note
// text, archive bytes, revision histories, tags or existing user links.
struct VirtualMemorySheet: View {
    @EnvironmentObject private var model: WorkOSModel
    @Environment(\.dismiss) private var dismiss
    @State private var showClearConfirmation = false
    @State private var query = ""

    let sourceKind: String
    let sourceID: String
    let sourceTitle: String

    private var segments: [VirtualMemory] {
        let all = model.virtualMemories(kind: sourceKind, id: sourceID)
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if term.isEmpty { return all }
        return all.filter { $0.title.localizedCaseInsensitiveContains(term) || $0.label.contains(term) }
    }

    private var isCurrent: Bool {
        model.isAnalyzingVirtual && model.virtualAnalysisTarget == sourceKind + ":" + sourceID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("가상 메모 색인").font(.title2.bold())
                    Text(sourceTitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Button("닫기") { dismiss() }
            }
            Text("원본을 쪼개지 않습니다. 구간의 줄 위치와 AI가 제안한 제목·분류를 별도 저장합니다. 복사한 임시 자료도 삭제하거나 검색에서 제외하지 않습니다.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button { model.startVirtualAnalysis(kind: sourceKind, id: sourceID, useAI: false) } label: {
                    Label("빠른 초안 생성", systemImage: "text.alignleft")
                }
                .disabled(model.isAnalyzingVirtual)
                Button { model.startVirtualAnalysis(kind: sourceKind, id: sourceID, useAI: true) } label: {
                    Label("로컬 AI로 구간 분석", systemImage: "brain")
                }
                .disabled(model.isAnalyzingVirtual)
                if isCurrent { Button("분석 취소") { model.stopVirtualAnalysis() } }
                Spacer()
                if !model.virtualMemories(kind: sourceKind, id: sourceID).isEmpty {
                    Button("가상 색인 제거", role: .destructive) { showClearConfirmation = true }
                        .disabled(model.isAnalyzingVirtual)
                }
            }
            .controlSize(.small)
            if isCurrent { ProgressView(value: model.virtualAnalysisProgress) }
            Text(model.virtualAnalysisStatus).font(.caption2).foregroundStyle(.secondary).lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            if model.staleVirtualSources.contains(sourceKind + ":" + sourceID) {
                Label("원문이 수정되어 이전 줄 범위는 표시하지 않습니다. 다시 분석하면 갱신됩니다.",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
            Divider()
            HStack {
                Text("구간 \(model.virtualMemories(kind: sourceKind, id: sourceID).count)개")
                    .font(.headline)
                Spacer()
                TextField("제목·분류 찾기", text: $query)
                    .textFieldStyle(.roundedBorder).frame(width: 210)
            }
            if segments.isEmpty {
                ContentUnavailableView("아직 가상 메모가 없습니다", systemImage: "text.book.closed",
                    description: Text("빠른 초안으로 분할 상태를 확인한 뒤, 필요하면 Ollama로 문맥을 분석하세요."))
            } else {
                List(segments) { segment in
                    Button {
                        model.openVirtualMemory(segment)
                        dismiss()
                    } label: {
                        HStack(alignment: .top, spacing: 13) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(segment.title).font(.subheadline.bold()).foregroundStyle(.primary)
                                Text("\(segment.lineLabel) · \(segment.label) · \(segment.aiReviewed ? "AI 제안" : "규칙 기반 초안")")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right.square").foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                .listStyle(.inset)
            }
            Text("가상 제목·분류는 추정 정보입니다. 원문은 열어 확인할 수 있습니다. 기억 지도에서 '의미 색인 실행'을 누르면 bge-m3가 구간 사이의 관계를 계산합니다.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(minWidth: 730, minHeight: 530)
        .onAppear {
            if !model.aiConnected && !model.isCheckingAI {
                Task { await model.checkAI() }
            }
        }
        .confirmationDialog("가상 메모 구간 정보만 삭제할까요? 원본과 다른 메모는 그대로 둡니다.",
            isPresented: $showClearConfirmation) {
            Button("가상 색인 제거", role: .destructive) {
                model.clearVirtualAnalysis(kind: sourceKind, id: sourceID)
            }
        }
    }
}
