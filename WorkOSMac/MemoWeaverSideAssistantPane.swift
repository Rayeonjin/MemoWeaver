import SwiftUI

/// Contextual access to the existing local-first RAG workflow.
/// It never mutates the open note, and only asks Ollama on explicit submit.
struct MemoWeaverSideAssistantPane: View {
    @EnvironmentObject private var model: WorkOSModel
    let noteID: String

    private var noteTitle: String {
        model.notes.first(where: { $0.id == noteID })?.visibleTitle ?? "현재 메모"
    }

    private var canAsk: Bool {
        model.aiConnected && !model.aiBusy &&
            !model.aiQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Label("AI에게 기록 질문", systemImage: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer(minLength: 4)
                    Button { model.selectedPage = .assistant } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }
                    .buttonStyle(.plain)
                    .memoTooltip("AI 전체 화면")
                    Button {
                        Task { await model.checkAI() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isCheckingAI)
                    .memoTooltip("로컬 Ollama 연결 확인")
                }
                Text("현재 메모: " + noteTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
                Text("질문을 보내면 전체 메모·기존 자료에서 근거를 찾습니다. 현재 메모만으로 범위를 제한하는 기능은 아직 아닙니다.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !model.aiConnected {
                    Label(model.isCheckingAI ? "Ollama 확인 중" : "Ollama 연결 필요", systemImage: "circle.dotted")
                        .font(.caption).foregroundStyle(.secondary)
                }
                TextEditor(text: $model.aiQuestion)
                    .font(.system(size: 13))
                    .frame(minHeight: 92, maxHeight: 138)
                    .overlay(RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(Color.secondary.opacity(0.25)))
                    .accessibilityLabel("AI에게 질문할 내용")
                Button("현재 메모와 관련된 이전 기록 찾기") {
                    model.aiQuestion = "'" + noteTitle + "'와 관련된 과거 메모의 결정사항, 후속 작업과 출처를 알려줘."
                }
                .buttonStyle(.link)
                .font(.caption)
                HStack {
                    if model.aiBusy {
                        ProgressView().controlSize(.small)
                        Button("중단") { model.stopAI() }
                    } else {
                        Button { model.askAI() } label: {
                            Label("근거 찾아 답변", systemImage: "sparkles")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canAsk)
                    }
                    Spacer(minLength: 0)
                }
                Divider()
                if !model.aiError.isEmpty {
                    Text(model.aiError).font(.caption).foregroundStyle(.red).textSelection(.enabled)
                } else if model.aiResponse.isEmpty {
                    Text("질문하면 답변과 확인 가능한 원문을 이곳에 표시합니다.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(model.aiResponse)
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                    Text("AI가 관계를 확정하거나 메모 원문을 변경하지 않습니다. 중요한 내용은 원문을 확인하세요.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if !model.aiSources.isEmpty {
                    Divider()
                    Text("참고한 원문 \(model.aiSources.count)건")
                        .font(.subheadline.bold())
                    ForEach(model.aiSources.indices, id: \.self) { index in
                        let source = model.aiSources[index]
                        Button {
                            model.openSource(source)
                        } label: {
                            HStack(alignment: .top, spacing: 6) {
                                Text("[\(index + 1)]").font(.caption.monospacedDigit())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(source.title).font(.caption.bold()).lineLimit(2)
                                    Text(source.subtitle).font(.caption2)
                                        .foregroundStyle(.secondary).lineLimit(2)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.up.right").font(.caption2)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(7)
                        .background(Color(nsColor: .controlBackgroundColor),
                                    in: RoundedRectangle(cornerRadius: 7))
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            model.loadMemoryCache()
            if !model.aiConnected && !model.isCheckingAI {
                Task { await model.checkAI() }
            }
        }
    }
}
