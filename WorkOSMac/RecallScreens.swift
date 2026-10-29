import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct GlobalRecallSearchScreen: View {
    @EnvironmentObject private var model: WorkOSModel
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    @State private var matches: [MemorySource] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var searchWorker: Task<[MemorySource], Never>?
    @State private var searching = false

    private func scheduleSearch() {
        searchTask?.cancel()
        searchWorker?.cancel()
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            matches = []
            searching = false
            return
        }
        searching = true
        searchTask = Task { @MainActor in
            // Debounce typing and cancel stale heavy scans before they start.
            do { try await Task.sleep(nanoseconds: 260_000_000) }
            catch { return }
            guard !Task.isCancelled else { return }
            let allNotes = model.notes
            let allChunks = model.chunks
            let segments = model.virtualMemories
            let texts = model.virtualSourceTexts()
            let worker = Task.detached(priority: .userInitiated) {
                WorkOSSearch.find(question: term, notes: allNotes,
                    chunks: allChunks, limit: 45,
                    virtualMemories: segments, virtualSourceTexts: texts)
            }
            searchWorker = worker
            var found = await worker.value
            guard !Task.isCancelled, query.trimmingCharacters(in: .whitespacesAndNewlines) == term else { return }
            let lower = term.lowercased()
            for note in allNotes where note.deletedAt.isEmpty {
                if model.typeName(note.typeID).lowercased().contains(lower) ||
                   model.notebookNames(for: note).joined(separator: " ").lowercased().contains(lower) {
                    let candidate = MemorySource(id: "category:" + note.id, kind: "note",
                        sourceID: note.id, title: note.visibleTitle,
                        subtitle: model.typeName(note.typeID) + " / " + model.notebookNames(for: note).joined(separator: ", "),
                        text: String(note.plainBody.prefix(550)), fromLine: 0, toLine: 0, score: 6)
                    if !found.contains(where: { $0.kind == "note" && $0.sourceID == note.id }) {
                        found.append(candidate)
                    }
                }
            }
            matches = Array(found.prefix(65))
            searching = false
            searchWorker = nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("모든 기록 검색", systemImage: "magnifyingglass")
                    .font(.title2.bold())
                Spacer()
                Text("메모 · 종류 · 노트북 · TXT 원문")
                    .font(.caption).foregroundStyle(.secondary)
            }
            TextField("메모 제목, 본문, 노트북 이름, 과거 파일 내용 검색", text: $query)
                .focused($searchFocused)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
            Divider()
            if searching {
                ProgressView("기록 검색 중…")
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ContentUnavailableView("찾고 싶은 기억을 입력하세요", systemImage: "text.magnifyingglass",
                    description: Text("키워드로 모든 기록을 검색합니다. 의미 검색과 자연어 질문은 AI 기억 비서에서 이용하세요."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack {
                    Text("검색 결과 \(matches.count)건 (최대 65건)")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(matches) { source in
                            Button { model.openSource(source) } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: source.kind == "archive" ? "archivebox" : "doc.text")
                                        .frame(width: 20)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(source.title).font(.subheadline.bold())
                                        Text(source.subtitle).font(.caption2).foregroundStyle(.secondary)
                                        Text(source.text.replacingOccurrences(of: "\n", with: " "))
                                            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                }
                                .padding(12)
                                .background(Color.secondary.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(22)
        .onAppear {
            DispatchQueue.main.async { searchFocused = true }
            scheduleSearch()
        }
        .onChange(of: query) { _, _ in scheduleSearch() }
        .onDisappear {
            searchTask?.cancel()
            searchWorker?.cancel()
        }
    }
}

struct WorkOSDailyJournalScreen: View {
    @EnvironmentObject private var model: WorkOSModel
    @State private var selectedDate = Date()
    @State private var didCopy = false

    private var day: String { WorkOSDate.day(selectedDate) }
    private var entries: [WorkNote] {
        model.notes.filter { $0.deletedAt.isEmpty && (
            $0.noteDate == day || $0.updatedAt.hasPrefix(day) ||
            $0.progress.contains { WorkOSJSON.string($0, "noteDate") == day })
        }.sorted { $0.updatedAt > $1.updatedAt }
    }
    private var progressEntries: [(note: WorkNote, text: String)] {
        var result: [(note: WorkNote, text: String)] = []
        for note in entries {
            for item in note.progress where WorkOSJSON.string(item, "noteDate") == day {
                result.append((note, HTMLText.plain(WorkOSJSON.string(item, "body"))))
            }
        }
        return result
    }
    private var dueItems: [WorkScheduleItem] {
        model.scheduleItems.filter { $0.dueDay == day }
            .sorted { $0.dueTime < $1.dueTime }
    }
    private var markdown: String {
        var output = "# 업무일지 \(day)\n\n## 기록 및 변경된 메모\n"
        if entries.isEmpty { output += "- 기록 없음\n" }
        for note in entries {
            output += "- \(note.visibleTitle) · \(model.typeName(note.typeID)) · \(note.status)\n"
        }
        output += "\n## 마감 및 확인 일정\n"
        if dueItems.isEmpty { output += "- 예정 일정 없음\n" }
        for item in dueItems {
            output += "- [\(item.isCompleted ? "x" : " ")] \(item.title) · \(item.dueTime.isEmpty ? "종일" : item.dueTime)\n"
        }
        output += "\n## 진행 기록\n"
        if progressEntries.isEmpty { output += "- 기록 없음\n" }
        for value in progressEntries {
            output += "- \(value.note.visibleTitle): \(value.text)\n"
        }
        return output
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Label("자동 업무일지", systemImage: "calendar")
                    .font(.title2.bold())
                Spacer()
                DatePicker("기록일", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.field)
                Button("Markdown 복사") {
                    NSPasteboard.general.clearContents()
                    didCopy = NSPasteboard.general.setString(markdown, forType: .string)
                }
                Button(".md로 저장") { exportJournal() }
            }
            Text("각 노트의 작성·수정 날짜와 해당 날짜에 추가한 진행 기록을 자동 취합합니다. AI가 작성한 추정 내용은 넣지 않습니다.")
                .font(.caption).foregroundStyle(.secondary)
            if didCopy { Text("클립보드에 복사했습니다.").font(.caption).foregroundStyle(.green) }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    Text("\(day) · 관련 메모 \(entries.count)개 · 진행 추가 \(progressEntries.count)건")
                        .font(.headline)
                    ForEach(entries) { note in
                        Button { model.openMemoryEntity("note:" + note.id) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(note.visibleTitle).font(.subheadline.bold())
                                    Text(model.typeName(note.typeID) + " · " + model.notebookNames(for: note).joined(separator: ", ") + " · " + note.status)
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .padding(10)
                            .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain)
                    }
                    Divider()
                    Text("이 날의 마감 및 확인 일정").font(.headline)
                    if dueItems.isEmpty {
                        Text("이 날짜의 마감 일정이 없습니다.").foregroundStyle(.secondary)
                    }
                    ForEach(dueItems) { item in
                        HStack {
                            Button { model.toggleScheduleComplete(item) } label: {
                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            }.buttonStyle(.borderless)
                            Text(item.title).font(.subheadline)
                            Spacer()
                            Text(item.dDay).font(.caption.monospacedDigit())
                            if !item.noteID.isEmpty {
                                Button("연결 메모") { model.openSchedule(item.id) }.font(.caption)
                            }
                        }
                    }
                    Divider()
                    Text("날짜별 진행 기록").font(.headline)
                    if progressEntries.isEmpty {
                        Text("이 날짜에 추가한 진행 기록이 없습니다.").foregroundStyle(.secondary)
                    }
                    ForEach(progressEntries.indices, id: \.self) { i in
                        let value = progressEntries[i]
                        VStack(alignment: .leading, spacing: 5) {
                            Text(value.note.visibleTitle).font(.caption.bold())
                            Text(value.text).textSelection(.enabled)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(22)
    }

    private func exportJournal() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "MemoWeaver_업무일지_\(day).md"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try markdown.write(to: url, atomically: true, encoding: .utf8)
            model.statusMessage = "업무일지 저장: \(url.lastPathComponent)"
        } catch { model.show(error) }
    }
}
