import SwiftUI

// Quick navigation is intentionally a *title-only, in-memory* lookup. It
// never starts AI, indexes documents, scans archive content, or writes notes.
// "전체 기록 검색" hands off to the existing deep search workflow.
struct MemoWeaverQuickSearchPalette: View {
    @EnvironmentObject private var model: WorkOSModel
    @Environment(\.dismiss) private var dismiss
    @State private var query: String
    @FocusState private var searchFocused: Bool
    let onToggleFocus: () -> Void

    init(initialQuery: String = "", onToggleFocus: @escaping () -> Void) {
        _query = State(initialValue: initialQuery)
        self.onToggleFocus = onToggleFocus
    }

    private enum Action: String, CaseIterable, Identifiable {
        case allSearch = "모든 기록 검색"
        case newNote = "새 메모 작성"
        case notes = "메모 목록"
        case journal = "업무일지"
        case planner = "일정"
        case memory = "기억 지도"
        case assistant = "AI 기억 비서"
        case focus = "집중 모드 전환"
        var id: Self { self }
        var symbol: String {
            switch self {
            case .allSearch: return "text.magnifyingglass"
            case .newNote: return "square.and.pencil"
            case .notes: return "note.text"
            case .journal: return "calendar"
            case .planner: return "calendar.badge.clock"
            case .memory: return "point.3.connected.trianglepath.dotted"
            case .assistant: return "brain.head.profile"
            case .focus: return "arrow.up.left.and.arrow.down.right"
            }
        }
    }

    private var matchingNotes: [WorkNote] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return Array(model.notes.lazy.filter { note in
            note.deletedAt.isEmpty && (term.isEmpty || note.visibleTitle.localizedStandardContains(term))
        }.prefix(12))
    }
    private var matchingActions: [Action] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return Action.allCases.filter { term.isEmpty || $0.rawValue.localizedStandardContains(term) }
    }
    private func perform(_ action: Action) {
        dismiss()
        switch action {
        case .allSearch: model.selectedPage = .search
        case .newNote: model.newNoteFromShortcut()
        case .notes: model.selectedPage = .all
        case .journal: model.selectedPage = .today
        case .planner: model.selectedPage = .planner
        case .memory: model.selectedPage = .memory
        case .assistant: model.selectedPage = .assistant
        case .focus: onToggleFocus()
        }
    }
    private func openNote(_ note: WorkNote) {
        dismiss()
        model.openNote(note.id)
    }
    private func chooseDefault() {
        if let first = matchingNotes.first, !query.isEmpty { openNote(first) }
        else if let first = matchingActions.first { perform(first) }
        else { perform(.allSearch) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("메모 제목 또는 명령 검색", text: $query)
                    .focused($searchFocused)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .onSubmit(chooseDefault)
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .memoTooltip("Esc")
                .accessibilityLabel("검색 닫기")
            }
            .padding(13)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
            Text("빠른 검색은 제목만 찾습니다. 본문·과거 TXT 검색은 ‘모든 기록 검색’을 선택하세요.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    if !matchingNotes.isEmpty {
                        Text(query.isEmpty ? "최근 메모" : "메모 제목 결과")
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        ForEach(matchingNotes) { note in
                            Button { openNote(note) } label: {
                                HStack(spacing: 9) {
                                    Image(systemName: "doc.text").frame(width: 18)
                                    Text(note.visibleTitle).lineLimit(1)
                                    Spacer()
                                    Image(systemName: "return").font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .contentShape(Rectangle())
                                .padding(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if !matchingActions.isEmpty {
                        Text("명령")
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            .padding(.top, 4)
                        ForEach(matchingActions) { action in
                            Button { perform(action) } label: {
                                HStack(spacing: 9) {
                                    Image(systemName: action.symbol).frame(width: 18)
                                    Text(action.rawValue)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .padding(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if matchingNotes.isEmpty && matchingActions.isEmpty {
                        Button("일치하는 제목이 없습니다 · 모든 기록 검색 열기") {
                            perform(.allSearch)
                        }
                        .buttonStyle(.borderless)
                        .padding(8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(width: 550, height: 475)
        .onAppear { DispatchQueue.main.async { searchFocused = true } }
        .onExitCommand { dismiss() }
    }
}
