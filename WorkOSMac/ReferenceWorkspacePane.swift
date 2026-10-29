import AppKit
import SwiftUI

// A reading workspace adjacent to the active editor. Unlike the global search
// screen or the reader window, it can keep several references expanded at once.
// Its search/expand/preview/copy actions NEVER change selectedNoteID.
struct ReferenceWorkspacePane: View {
    @EnvironmentObject private var model: WorkOSModel
    let currentNoteID: String
    let caretLine: Int
    @Binding var query: String

    @State private var mode = "linked"
    @State private var linked: [ReferencePanelEntry] = []
    @State private var results: [MemorySource] = []
    @State private var didSearch = false
    @State private var expandedIDs: Set<String> = []
    @State private var editTargetID = ""
    @State private var editKind = "related"
    @State private var editMemo = ""
    @State private var showLinkEditor = false
    @State private var searchTask: Task<Void, Never>?
    @State private var searchWorker: Task<[MemorySource], Never>?
    @State private var isSearching = false
    @State private var recentlyRemovedLink: MemoryLink?

    private var sourceID: String { "note:" + currentNoteID }
    private var focusedID: String { model.sideMemoryCenter(noteID: currentNoteID, caretLine: caretLine) }
    private var contextIDs: [String] {
        focusedID == sourceID ? [sourceID] : [sourceID, focusedID]
    }
    private var available: Set<String> {
        var ids = Set<String>()
        for note in model.activeNotes { ids.insert("note:" + note.id) }
        for archive in model.archives { ids.insert("archive:" + archive.id) }
        for item in model.virtualMemories {
            if !model.staleVirtualSources.contains(item.sourceKind + ":" + item.sourceID) {
                ids.insert("virtual:" + item.id)
            }
        }
        return ids
    }

    private func refreshLinked() {
        let contexts = contextIDs
        let confirmed = model.confirmedMemoryLinks.filter { link in
            contexts.contains(link.first) || contexts.contains(link.second)
        }
        // sideInferredRelations excludes hidden/stale and ungrounded AI findings.
        var inferred: [MemoryInferredRelation] = []
        var keys = Set<String>()
        for context in contexts {
            for relation in model.sideInferredRelations(centerID: context) where !keys.contains(relation.id) {
                keys.insert(relation.id)
                inferred.append(relation)
            }
        }
        linked = ReferencePanelCore.related(centers: contexts, confirmed: confirmed,
                                             inferred: inferred, valid: available)
    }

    private func performSearch() {
        searchTask?.cancel()
        searchWorker?.cancel()
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        didSearch = true
        mode = "search"
        guard !term.isEmpty else { results = []; isSearching = false; return }
        isSearching = true
        searchTask = Task { @MainActor in
            let allNotes = model.notes
            let allChunks = model.chunks
            let segments = model.virtualMemories
            let sourceTexts = model.virtualSourceTexts()
            let worker = Task.detached(priority: .userInitiated) {
                WorkOSSearch.find(question: term, notes: allNotes,
                    chunks: allChunks, limit: 55,
                    virtualMemories: segments, virtualSourceTexts: sourceTexts)
            }
            searchWorker = worker
            let found = await worker.value
            guard !Task.isCancelled, query.trimmingCharacters(in: .whitespacesAndNewlines) == term else { return }
            results = found
            isSearching = false
            searchWorker = nil
        }
    }

    private func manualLink(to target: String) -> MemoryLink? {
        model.confirmedMemoryLinks.first { $0.id == MemoryLink(sourceID, target).id }
    }

    private func canLink(_ target: String) -> Bool {
        guard !currentNoteID.isEmpty && target != sourceID else { return false }
        if let virtual = model.virtualMemories.first(where: { "virtual:" + $0.id == target }) {
            // An extracted section of the *same* active note is not an external reference.
            return !(virtual.sourceKind == "note" && virtual.sourceID == currentNoteID)
        }
        return available.contains(target)
    }

    private func openLinkEditor(_ target: String) {
        guard canLink(target) else { return }
        let previous = manualLink(to: target)
        editTargetID = target
        editKind = previous?.relationKind ?? "related"
        editMemo = previous?.memo ?? ""
        showLinkEditor = true
    }

    private func linkNow(_ target: String) {
        guard canLink(target) else { return }
        model.addConfirmedMemoryLink(sourceID, target)
        refreshLinked()
    }

    private func unlink(_ target: String) {
        let previous = manualLink(to: target)
        model.removeConfirmedMemoryLink(sourceID, target)
        // Undo restores the exact human-authored relation type and explanation.
        if previous != nil && manualLink(to: target) == nil { recentlyRemovedLink = previous }
        refreshLinked()
    }

    private func undoUnlink() {
        guard let previous = recentlyRemovedLink else { return }
        model.addConfirmedMemoryLink(previous.first, previous.second,
            relationKind: previous.relationKind, memo: previous.memo,
            replaceExisting: true)
        recentlyRemovedLink = nil
        refreshLinked()
    }

    // Each SwiftUI expression stays small. Apple CLT swiftc can time out when
    // two result collections, nested conditionals and dozens of modifiers are
    // inferred in a single ViewBuilder (the former monolithic list failure).
    var body: some View {
        layout
            .sheet(isPresented: $showLinkEditor) { manualLinkEditor }
            .onAppear(perform: performInitialLoad)
            .onChange(of: currentNoteID) { _, _ in
                expandedIDs.removeAll()
                refreshLinked()
            }
            .onChange(of: focusedID) { _, _ in refreshLinked() }
            .onChange(of: model.confirmedMemoryLinks) { _, _ in refreshLinked() }
            .onChange(of: model.inferredMemoryRelations) { _, _ in refreshLinked() }
            .onChange(of: model.memoryRelationReviews) { _, _ in refreshLinked() }
            .onDisappear {
                searchTask?.cancel()
                searchWorker?.cancel()
            }
    }

    private var layout: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            searchControls
            modePicker
            modeControls
            Divider()
            ScrollView { resultList }
        }
    }

    private var header: some View {
        HStack {
            Label("참고 메모 · 읽기 전용", systemImage: "books.vertical")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text("편집 중인 메모 유지")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 9)
    }

    private var modePicker: some View {
        Picker("참고 목록", selection: $mode) {
            Text("연결된 메모 · \(linked.count)").tag("linked")
            Text("검색").tag("search")
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder private var modeControls: some View {
        if mode == "linked" { linkedControls }
        else {
            Text(didSearch ? "검색 결과 · 현재 편집 메모 유지" : "검색어를 입력한 뒤 Return 또는 검색을 누르세요.")
                .font(.caption2).foregroundStyle(.secondary)
                .padding(.horizontal, 12).padding(.bottom, 9)
            if isSearching {
                ProgressView("검색 중…")
                    .controlSize(.small)
                    .padding(.horizontal, 12).padding(.bottom, 6)
            }
        }
    }

    private var searchControls: some View {
        HStack(spacing: 6) {
            TextField("제목·내용·과거 기록 검색", text: $query)
                .textFieldStyle(.roundedBorder)
                .onSubmit(performSearch)
            Button("검색", action: performSearch)
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var linkedControls: some View {
        HStack {
            Text("수동 연결 · 근거가 확인된 AI 관계")
                .font(.caption2).foregroundStyle(.secondary)
            Spacer()
            if recentlyRemovedLink != nil {
                Button("연결 해제 취소", action: undoUnlink)
                    .memoTooltip("방금 해제한 수동 연결과 설명을 복원")
            }
            Button(allExpanded ? "모두 접기" : "모두 펼치기", action: toggleAll)
                .controlSize(.mini)
                .disabled(linked.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 9)
    }

    private var allExpanded: Bool {
        let first = Set(linked.prefix(40).map(\.id))
        return !first.isEmpty && first.isSubset(of: expandedIDs)
    }

    private func toggleAll() {
        let first = Set(linked.prefix(40).map(\.id))
        if first.isSubset(of: expandedIDs) { expandedIDs.subtract(first) }
        else { expandedIDs.formUnion(first) }
    }

    @ViewBuilder private var resultList: some View {
        if mode == "linked" {
            ReferenceLinkedRows(entries: linked, expandedIDs: expandedIDs,
                                sourceID: sourceID, actions: rowActions)
        } else {
            ReferenceSearchRows(results: results, didSearch: didSearch,
                                expandedIDs: expandedIDs, sourceID: sourceID,
                                actions: rowActions)
        }
    }

    // Type-erased (plain Swift closures) actions keep the list ViewBuilders
    // independent from the parent WorkOSModel/@State inference graph.
    private var rowActions: ReferenceRowActions {
        ReferenceRowActions(
            toggle: { id in self.toggle(id) },
            canLink: { id in self.canLink(id) },
            connect: { id in self.linkNow(id) },
            edit: { id in self.openLinkEditor(id) },
            unlink: { id in self.unlink(id) })
    }

    private var manualLinkEditor: some View {
        let sourceTitle: String = model.memoryTitle(sourceID)
        let targetTitle: String = model.memoryTitle(editTargetID)
        return ManualMemoryLinkEditor(sourceTitle: sourceTitle,
            targetTitle: targetTitle, relationKind: $editKind, memo: $editMemo,
            onCancel: { showLinkEditor = false },
            onSave: saveManualLink)
    }

    private func saveManualLink() {
        model.addConfirmedMemoryLink(sourceID, editTargetID,
            relationKind: editKind, memo: editMemo, replaceExisting: true)
        refreshLinked()
        showLinkEditor = false
    }

    private func performInitialLoad() {
        refreshLinked()
    }

    private func toggle(_ id: String) {
        if expandedIDs.contains(id) { expandedIDs.remove(id) }
        else { expandedIDs.insert(id) }
    }
}

// Separate typed list Views, each with a single small ForEach. This prevents
// Apple CLT's SwiftUI type-checker from expanding the entire sidebar tree.
private struct ReferenceRowActions {
    let toggle: (String) -> Void
    let canLink: (String) -> Bool
    let connect: (String) -> Void
    let edit: (String) -> Void
    let unlink: (String) -> Void
}

private struct ReferenceLinkedRows: View {
    @EnvironmentObject private var model: WorkOSModel
    let entries: [ReferencePanelEntry]
    let expandedIDs: Set<String>
    let sourceID: String
    let actions: ReferenceRowActions

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 9) {
            if entries.isEmpty {
                ContentUnavailableView("연결된 메모가 없습니다", systemImage: "link.badge.plus",
                    description: Text("검색에서 과거 기록을 직접 연결하거나 기억 지도에서 AI 관계 분석을 실행할 수 있습니다."))
                    .frame(minHeight: 190)
            }
            ForEach(entries, id: \.id) { entry in
                row(entry)
            }
        }
        .padding(12)
    }

    private func row(_ entry: ReferencePanelEntry) -> ReferenceMemoRow {
        let target: String = entry.id
        let linkID: String = MemoryLink(sourceID, target).id
        let isLinked: Bool = model.confirmedMemoryLinks.contains(where: { $0.id == linkID })
        let name: String = model.memoryTitle(target)
        return ReferenceMemoRow(entityID: target, cardID: target,
            title: name, subtitle: entry.label, note: entry.detail,
            fromLine: entry.fromLine, toLine: entry.toLine,
            expanded: expandedIDs.contains(target),
            toggle: { actions.toggle(target) },
            manualLink: isLinked, canLink: actions.canLink(target),
            connect: { actions.connect(target) },
            editLink: { actions.edit(target) },
            unlink: { actions.unlink(target) })
    }
}

private struct ReferenceSearchRows: View {
    @EnvironmentObject private var model: WorkOSModel
    let results: [MemorySource]
    let didSearch: Bool
    let expandedIDs: Set<String>
    let sourceID: String
    let actions: ReferenceRowActions

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 9) {
            if !didSearch {
                ContentUnavailableView("필요한 기록 검색", systemImage: "magnifyingglass",
                    description: Text("검색한 메모를 펼쳐 읽고 현재 메모에 연결할 수 있습니다. 검색 중 AI를 실행하지 않습니다."))
                    .frame(minHeight: 190)
            } else if results.isEmpty {
                ContentUnavailableView("검색 결과 없음", systemImage: "text.magnifyingglass",
                    description: Text("검색어를 바꾸거나 전체 검색에서 다른 단어를 시도해 보세요."))
                    .frame(minHeight: 190)
            } else {
                Text("검색 결과 \(results.count)건 · 최대 55건")
                    .font(.caption2).foregroundStyle(.secondary)
                ForEach(results, id: \.id) { result in
                    row(result)
                }
            }
        }
        .padding(12)
    }

    private func row(_ result: MemorySource) -> ReferenceMemoRow {
        let target: String = ReferencePanelCore.entityID(for: result)
        let card: String = result.id
        let linkID: String = MemoryLink(sourceID, target).id
        let isLinked: Bool = model.confirmedMemoryLinks.contains(where: { $0.id == linkID })
        let excerpt: String = String(result.text.prefix(240))
        return ReferenceMemoRow(entityID: target, cardID: card,
            title: result.title, subtitle: result.subtitle, note: excerpt,
            fromLine: result.fromLine, toLine: result.toLine,
            expanded: expandedIDs.contains(card),
            toggle: { actions.toggle(card) },
            manualLink: isLinked, canLink: actions.canLink(target),
            connect: { actions.connect(target) },
            editLink: { actions.edit(target) },
            unlink: { actions.unlink(target) })
    }
}

// Keep the relation-edit sheet in an independent View so the parent ViewBuilder
// cannot trigger SwiftUI type-checker expression timeouts. All writes still go
// through ReferenceWorkspacePane.saveManualLink().
private struct ManualMemoryLinkEditor: View {
    let sourceTitle: String
    let targetTitle: String
    @Binding var relationKind: String
    @Binding var memo: String
    let onCancel: () -> Void
    let onSave: () -> Void

    private var relationDescription: String {
        sourceTitle + " ↔ " + targetTitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("수동 기억 연결")
                .font(.title3.bold())
            Text(verbatim: relationDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("관계 유형", selection: $relationKind) {
                ForEach(ReferencePanelCore.manualKinds) { kind in
                    Text(kind.label).tag(kind.code)
                }
            }
            TextField("연결 이유 (선택 사항)", text: $memo)
                .textFieldStyle(.roundedBorder)
            Text("이 연결은 사용자가 확정한 관계로 저장됩니다. AI가 자동으로 삭제하거나 변경하지 않습니다.")
                .font(.caption2).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("취소", action: onCancel)
                Button("저장", action: onSave)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(minWidth: 430)
    }
}

// The card is a separate small view so expensive document/HTML rendering only
// starts after a user expands it; unopened results are just text and buttons.
private struct ReferenceMemoRow: View {
    let entityID: String
    let cardID: String
    let title: String
    let subtitle: String
    let note: String
    let fromLine: Int
    let toLine: Int
    let expanded: Bool
    let toggle: () -> Void
    let manualLink: Bool
    let canLink: Bool
    let connect: () -> Void
    let editLink: () -> Void
    let unlink: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            rowHeader
            if expanded { expandedContent }
        }
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.secondary.opacity(0.10)))
    }

    private var rowHeader: some View {
        Button(action: toggle) {
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.caption).padding(.top, 3)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.subheadline.bold()).lineLimit(2)
                    Text(subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                    if !note.isEmpty && !expanded {
                        Text(note).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(10)
        }
        .buttonStyle(.plain)
    }

    private var expandedContent: some View {
        VStack(spacing: 0) {
            Divider()
            linkControls
            ReferenceMemoBody(entityID: entityID, title: title,
                              fromLine: fromLine, toLine: toLine)
        }
    }

    private var linkControls: some View {
        HStack(spacing: 8) {
            if manualLink {
                Label("직접 연결됨", systemImage: "link")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Button("유형·설명", action: editLink).controlSize(.mini)
                Button("연결 해제", role: .destructive, action: unlink).controlSize(.mini)
            } else if canLink {
                Spacer()
                Button(action: connect) {
                    Label("현재 메모에 연결", systemImage: "link.badge.plus")
                }
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
    }

}

private struct ReferenceMemoBody: View {
    @EnvironmentObject private var model: WorkOSModel
    let entityID: String
    let title: String
    let fromLine: Int
    let toLine: Int

    @State private var document: MemoryEvidenceDocument?
    @State private var loadedText = ""
    @State private var displayLimit = 5000
    @State private var renderedHTML: String?
    @State private var missing = false

    private var bodyText: String { loadedText }

    private var shown: (text: String, more: Bool) {
        ReferencePanelCore.limitedText(bodyText, maxCharacters: displayLimit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            content
        }
        .padding(10)
        .onAppear(perform: loadReference)
    }

    @ViewBuilder private var content: some View {
        if missing {
            Text("원문을 읽을 수 없습니다. 삭제 또는 가상 메모 재분석이 필요한 기록일 수 있습니다.")
                .font(.caption).foregroundStyle(.secondary)
        } else if document == nil {
            ProgressView().controlSize(.small)
        } else {
            renderedOrRaw
            if shown.more { moreButton }
            actionButtons
        }
    }

    @ViewBuilder private var renderedOrRaw: some View {
        if let renderedHTML {
            // Independent, locally sandboxed HTML preview, never an editor.
            WorkOSHTMLPreview(html: renderedHTML, focusLine: 1)
                .frame(height: 310)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            if shown.more {
                Text("긴 메모는 표시된 부분만 미리보기합니다. 원본은 변경되지 않습니다.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        } else {
            Text(shown.text.isEmpty ? "(본문 없음)" : shown.text)
                .font(.system(size: 12, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    private var moreButton: some View {
        Button("내용 더 보기") {
            displayLimit += 5000
            if renderedHTML != nil { renderedHTML = makeHTML() }
        }
        .controlSize(.mini)
    }

    private var actionButtons: some View {
        HStack(spacing: 7) {
            Button(action: switchPreview) {
                Label(renderedHTML == nil ? "미리보기" : "원문", systemImage: previewSymbol)
            }
            Button(action: copyReference) {
                Label("복사", systemImage: "doc.on.doc")
            }
            Button(action: openReader) {
                Label("별도 창", systemImage: "arrow.up.right.square")
            }
            Spacer(minLength: 0)
        }
        .controlSize(.small)
        .labelStyle(.titleAndIcon)
    }

    private var previewSymbol: String {
        renderedHTML == nil ? "eye" : "chevron.left.forwardslash.chevron.right"
    }

    private func switchPreview() {
        if renderedHTML == nil { renderedHTML = makeHTML() }
        else { renderedHTML = nil }
    }

    private func copyReference() {
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(bodyText, forType: .string)
    }

    private func openReader() {
        model.openReferenceEntity(entityID, fromLine: fromLine, toLine: toLine)
    }

    private func loadReference() {
        guard let database = model.database else { missing = true; return }
        do {
            document = try database.evidenceDocument(entityID: entityID)
            missing = document == nil
            if let document {
                if fromLine > 0 && toLine >= fromLine && !entityID.hasPrefix("virtual:") {
                    let lines = VirtualMemoryCore.lines(document.text)
                    let first = max(1, fromLine - 6)
                    let last = min(lines.count, toLine + 6)
                    loadedText = VirtualMemoryCore.sourceText(document.text,
                        from: first, to: last)
                } else {
                    loadedText = document.text
                }
            }
        } catch { missing = true }
    }

    private func makeHTML() -> String {
        let shownSource = shown.text
        if document != nil && entityID.hasPrefix("note:") && !shown.more && fromLine == 0,
           let note = model.notes.first(where: { "note:" + $0.id == entityID }), !note.isMarkdown {
            return NoteDocuments.html(note: note)
        }
        return NoteDocuments.markdownPreviewHTML(title: title, noteDate: "", status: "읽기 전용",
                                                  markdown: shownSource)
    }
}
