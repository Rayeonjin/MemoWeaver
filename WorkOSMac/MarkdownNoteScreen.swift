import AppKit
import Combine
import SwiftUI

// Unified plain-text editor for all notes. The conversion of legacy HTML is
// display-only until a real text edit; first save archives original HTML/blocks
// and creates a WAL-consistent snapshot before switching the body format.
struct MarkdownNoteEditorScreen: View {
    @EnvironmentObject private var model: WorkOSModel
    @AppStorage("memoryhome.typography.fontSize") private var fontSize = EditorTypographyRules.defaultSize
    @AppStorage(MarkdownPreviewMode.defaultsKey) private var previewModeRaw = MarkdownPreviewMode.memo.rawValue
    @AppStorage("memoweaver.editor.syntaxColorsEnabled") private var syntaxColorsEnabled = true
    let note: WorkNote
    let listPaneVisible: Bool
    let auxiliaryPaneVisible: Bool
    let focusMode: Bool
    let previewActive: Bool
    @Binding var previewHTML: String
    @Binding var previewCaretLine: Int
    let openPreview: () -> Void

    @State private var draft: String
    @State private var title: String
    @State private var typeID: String
    @State private var bookID: String
    @State private var notebookIDs: [String]
    @State private var noteDay: Date
    @State private var noteStatus: String
    @State private var sourceURL: String
    @State private var pinned: Bool
    @State private var showAdditionalInfo = false
    @State private var showHistory = false
    @State private var confirmDelete = false
    @State private var insertRequest: MarkdownInsertRequest?
    @State private var editorContext: MarkdownEditingContext = .normal
    @State private var pendingSave: Task<Void, Never>?
    @State private var pendingPreview: Task<Void, Never>?
    @State private var previewRevision = 0
    @State private var pendingPreviewFirstChangeAt: TimeInterval?
    @State private var saveLabel: String
    @State private var isDirty = false
    @State private var bodyEdited = false
    @State private var progressText = ""
    @State private var caretColumn = 1
    @State private var currentCaretLine = 1
    @State private var totalLines = 1
    @State private var characterCount = 0
    @State private var pendingCharacterCount: Task<Void, Never>?
    @State private var pendingRecoveryWrite: Task<Void, Never>?
    @State private var recoveryDraft: MemoWeaverRecoveryDraft?
    @State private var editorSession = UUID()
    @State private var editedRevision = 0
    @State private var mountGeneration: UUID?

    init(note: WorkNote, listPaneVisible: Bool, auxiliaryPaneVisible: Bool,
         focusMode: Bool, previewActive: Bool, previewHTML: Binding<String>,
         previewCaretLine: Binding<Int>, openPreview: @escaping () -> Void) {
        self.note = note
        self.listPaneVisible = listPaneVisible
        self.auxiliaryPaneVisible = auxiliaryPaneVisible
        self.focusMode = focusMode
        self.previewActive = previewActive
        _previewHTML = previewHTML
        _previewCaretLine = previewCaretLine
        self.openPreview = openPreview
        let editable = LegacyNoteTextConverter.editableText(for: note)
        _draft = State(initialValue: editable)
        _totalLines = State(initialValue: MemoWeaverUIRules.totalLines(in: editable))
        _characterCount = State(initialValue: editable.count)
        _saveLabel = State(initialValue: note.isMarkdown ? "저장됨" : "기존 원본 보존 중")
        _title = State(initialValue: note.title)
        _typeID = State(initialValue: note.typeID)
        _bookID = State(initialValue: note.bookID)
        _notebookIDs = State(initialValue: note.notebookIDs)
        _noteDay = State(initialValue: WorkOSDate.parseDay(note.noteDate))
        _noteStatus = State(initialValue: note.status)
        _sourceURL = State(initialValue: note.sourceURL)
        _pinned = State(initialValue: note.pinned)
    }

    private var displayTitle: String {
        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return title }
        return MemoWeaverUIRules.titleSuggestion(draft)
    }

    private func updateCharacterCountLater() {
        pendingCharacterCount?.cancel()
        let snapshot = draft
        pendingCharacterCount = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 260_000_000)
            guard !Task.isCancelled else { return }
            let result = await Task.detached(priority: .utility) { snapshot.count }.value
            if !Task.isCancelled { characterCount = result }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                if let recoveryDraft { recoveryBanner(recoveryDraft) }
                MemoWeaverEditorHeader(
                    listPaneVisible: listPaneVisible, auxiliaryPaneVisible: auxiliaryPaneVisible,
                    focusMode: focusMode,
                    title: $title, typeID: $typeID, bookID: $bookID,
                    notebookIDs: $notebookIDs, pinned: $pinned,
                    noteDay: $noteDay, noteStatus: $noteStatus,
                    sourceURL: $sourceURL, progressText: $progressText,
                    onAddProgress: addProgress,
                    onTrash: { confirmDelete = true },
                    onRestore: { model.markDeleted(note, deleted: false) },
                    isTrashed: !note.deletedAt.isEmpty,
                    fallbackTitle: displayTitle,
                    onAdditionalInfo: { showAdditionalInfo = true },
                    onCheckpoint: { flush(checkpoint: true) },
                    onHistory: { showHistory = true }, onExport: export)
                if !note.isMarkdown {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield")
                        Text(LegacyNoteTextConverter.containsComplexContent(note.bodyHTML)
                             ? "이 메모에는 복잡한 HTML 요소가 있습니다. 편집 전 내용을 확인하세요. 최초 변경 시 원본·백업이 보존됩니다."
                             : "기존 메모는 텍스트로 표시합니다. 첫 본문 변경 시 원본 HTML을 백업한 뒤 Markdown으로 저장합니다.")
                    }
                    .font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(2)
                }
                Spacer(minLength: 4)
                Group {
                if editorContext == .normal || editorContext == .code {
                    MemoWeaverInsertToolbar { kind in
                        insertRequest = MarkdownTemplates.insertion(for: kind)
                    } onInsertChart: { chart in
                        insertRequest = MermaidChartTemplates.insertion(for: chart)
                    } onInsertDiagram: { diagram in
                        insertRequest = MermaidDiagramTemplates.insertion(for: diagram)
                    } onInsertTable: { columns, rows in
                        insertRequest = MarkdownTableGridCore.insertion(columns: columns, rows: rows)
                    } onInsertExtra: { item in
                        insertRequest = item.insertion()
                    } onInsertCode: { language in
                        insertRequest = language.insertion()
                    }
                } else {
                    MarkdownAssistPalette(context: editorContext) { snippet in
                        insertRequest = MarkdownInsertRequest(
                            source: snippet.source, caretBack: snippet.caretBack,
                            inlineSnippet: true, wrapsSelection: snippet.wrapsSelection,
                            beginsOnNewLine: snippet.beginsOnNewLine)
                    } onInsertAdvanced: { item in
                        insertRequest = item.insertion()
                    }
                }
                }
                .frame(height: 30, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .windowBackgroundColor))
            // Both the list filter stack and the editor chrome occupy one
            // shared band. Exceptional recovery/legacy warnings may grow.
            .frame(height: (recoveryDraft == nil && note.isMarkdown)
                ? MemoWeaverWorkspaceHeaderMetrics.height : nil, alignment: .top)
            Divider()
            MarkdownPlainEditor(initialText: draft,
                                insertRequest: insertRequest,
                                fontSize: fontSize, syntaxColorsEnabled: syntaxColorsEnabled, autoFocus: true,
                                focusLine: model.noteFocusNoteID == note.id ? model.noteFocusLine : 0,
                                focusRequestID: model.noteFocusRequestID,
                                restoreCaretOffset: model.editorCaretOffsets[note.id],
                                onImagePaste: { png in model.storePastedPNG(png, for: note.id) },
                                onImageImportError: { message in model.alertText = "붙여넣기 실패: " + message }) { value in
                guard draft != value else { return }
                draft = value
                model.editorWasUsed()
                bodyEdited = true
                scheduleSave()
                schedulePreview()
                updateCharacterCountLater()
            } onTemplateInsertion: {
                // AppKit templates may not deliver textDidChange. The editor
                // explicitly publishes the source first, then renders with
                // no debounce, including a newly inserted closed block.
                schedulePreview(immediate: true)
            } onContextChange: { context in
                editorContext = context
            } onCaretLineChange: { line in
                if previewCaretLine != line { previewCaretLine = line }
                model.editorWasUsed()
            } onCaretStatusChange: { line, column, count, offset in
                model.editorCaretOffsets[note.id] = offset
                currentCaretLine = line
                caretColumn = column
                totalLines = count
            }
            .frame(maxWidth: .infinity, minHeight: 160, maxHeight: .infinity)
            .id(editorSession)
            Divider()
            MemoWeaverEditorStatusBar(
                caretLine: currentCaretLine, caretColumn: caretColumn,
                totalLines: totalLines, characterCount: characterCount,
                saveLabel: saveLabel)
        }
        .frame(minWidth: 160)
        .onAppear {
            mountGeneration = model.dataGeneration
            refreshPreview()
            Task { @MainActor in
                guard let previous = await MemoWeaverDraftRecoveryStore.shared.read(noteID: note.id),
                      previous.storageEpoch == currentStorageEpoch,
                      previous.capturedAt > note.updatedAt,
                      previous.body != LegacyNoteTextConverter.editableText(for: note) ||
                      previous.title != note.title || previous.typeID != note.typeID ||
                      previous.bookID != note.bookID || previous.pinned != note.pinned else { return }
                recoveryDraft = previous
            }
        }
        .onChange(of: previewActive) { _, value in
            if value {
                refreshPreview()
            } else {
                pendingPreview?.cancel()
                pendingPreviewFirstChangeAt = nil
                previewRevision += 1 // invalidate already-running conversion
            }
        }
        .onChange(of: previewModeRaw) { _, _ in refreshPreview() }
        .onReceive(NotificationCenter.default.publisher(for: .memoWeaverNativeEditorCommand)) { notice in
            guard let info = notice.userInfo,
                  let commandNote = info["noteID"] as? String,
                  commandNote == note.id,
                  let action = info["action"] as? String else { return }
            switch action {
            case "title":
                if let next = info["value"] as? String, next != title { title = next }
            case "pin": pinned.toggle()
            case "details": showAdditionalInfo = true
            case "trash": confirmDelete = true
            case "restore": model.markDeleted(note, deleted: false)
            case "checkpoint": flush(checkpoint: true)
            case "history": showHistory = true
            case "exportMarkdown": export(.markdown)
            case "exportHTML": export(.html)
            case "exportPDF": export(.pdf)
            default: break
            }
        }
        .onChange(of: title) { _, _ in scheduleSave(); schedulePreview() }
        .onChange(of: typeID) { _, _ in scheduleSave() }
        .onChange(of: bookID) { oldID, newID in
            // AI classification may still set the legacy primary binding.
            // Keep already selected notebooks when the primary changes.
            if newID != (notebookIDs.first ?? "") {
                notebookIDs = NotebookMembershipCore.normalized(primary: newID,
                    ids: notebookIDs.filter { $0 != oldID })
            }
            scheduleSave()
        }
        .onChange(of: notebookIDs) { _, _ in scheduleSave() }
        .onChange(of: noteDay) { _, _ in scheduleSave(); schedulePreview() }
        .onChange(of: noteStatus) { _, _ in scheduleSave(); schedulePreview() }
        .onChange(of: sourceURL) { _, _ in scheduleSave() }
        .onChange(of: pinned) { _, _ in scheduleSave() }
        .onReceive(model.$checkpointSignal.dropFirst()) { _ in flush(checkpoint: true) }
        // Before compact/legacy shell switching, commit the current local draft
        // synchronously so the replacement editor reads fresh model content.
        .onReceive(NotificationCenter.default.publisher(for: .memoWeaverBeforeLayoutChange)) { notification in
            flush(checkpoint: false)
            (notification.object as? MemoWeaverLayoutCommitRequest)?.canProceed = !isDirty
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            flush(checkpoint: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            flush(checkpoint: false)
        }
        .onDisappear {
            pendingSave?.cancel()
            pendingPreview?.cancel()
            pendingPreviewFirstChangeAt = nil
            previewRevision += 1
            pendingCharacterCount?.cancel()
            pendingRecoveryWrite?.cancel()
            // Whole restore invalidated this editor's source. A stale onDisappear
            // must never overwrite a restored note with the old on-screen draft.
            if mountGeneration == model.dataGeneration { flush(checkpoint: false) }
        }
        .sheet(isPresented: $showAdditionalInfo) {
            MemoWeaverAdditionalNoteInfo(note: note, noteDay: $noteDay,
                noteStatus: $noteStatus, sourceURL: $sourceURL,
                progressText: $progressText, onAddProgress: addProgress,
                onDelete: { confirmDelete = true },
                onRestore: { model.markDeleted(note, deleted: false) })
        }
        .sheet(isPresented: $showHistory) {
            // Revision bodies remain raw source; HTML notes use their legacy history reader.
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(note.revisions.enumerated()), id: \.offset) { item in
                            let revision = item.element
                            VStack(alignment: .leading, spacing: 5) {
                                Text(WorkOSJSON.string(revision, "action", default: "저장 이력"))
                                    .font(.headline)
                                Text(WorkOSDate.display(WorkOSJSON.string(revision, "at")))
                                    .font(.caption).foregroundStyle(.secondary)
                                Text(WorkOSJSON.string(revision, "bodyFormat") == "markdown"
                                     ? WorkOSJSON.string(revision, "body")
                                     : LegacyNoteTextConverter.text(from: WorkOSJSON.string(revision, "body")))
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                            Divider()
                        }
                    }
                    .padding(18)
                }
                .navigationTitle("Markdown 변경 이력")
                .frame(minWidth: 610, minHeight: 400)
                .toolbar { Button("닫기") { showHistory = false } }
            }
        }
        .confirmationDialog("이 메모를 휴지통으로 이동하시겠습니까?", isPresented: $confirmDelete) {
            Button("휴지통으로 이동", role: .destructive) {
                flush(checkpoint: true)
                if saveLabel != "저장 실패", let saved = model.notes.first(where: { $0.id == note.id }) {
                    model.markDeleted(saved, deleted: true)
                }
            }
        }
    }

    private var currentStorageEpoch: String {
        UserDefaults.standard.string(forKey: "memoweaver.storage.recoveryEpoch") ?? "original"
    }

    private func recoverySnapshot() -> MemoWeaverRecoveryDraft {
        MemoWeaverRecoveryDraft(noteID: note.id, storageEpoch: currentStorageEpoch,
            baseRevision: note.updatedAt, capturedAt: WorkOSDate.now(),
            title: title, body: draft, typeID: typeID, bookID: bookID,
            notebookIDs: notebookIDs, noteDay: WorkOSDate.day(noteDay), status: noteStatus,
            sourceURL: sourceURL, pinned: pinned)
    }

    private func scheduleRecoveryWrite() {
        editedRevision += 1
        guard pendingRecoveryWrite == nil else { return }
        pendingRecoveryWrite = Task { @MainActor in
            do { try await Task.sleep(nanoseconds: 350_000_000) }
            catch { pendingRecoveryWrite = nil; return }
            guard isDirty, !Task.isCancelled else { pendingRecoveryWrite = nil; return }
            let revision = editedRevision
            let snapshot = recoverySnapshot()
            do { try await MemoWeaverDraftRecoveryStore.shared.write(snapshot) }
            catch { model.statusMessage = "임시 작성본 저장 실패: " + error.localizedDescription }
            pendingRecoveryWrite = nil
            // Periodic snapshots even during continuous typing (not trailing-only debounce).
            if isDirty && editedRevision != revision { scheduleRecoveryWrite() }
        }
    }

    private func recoveryBanner(_ saved: MemoWeaverRecoveryDraft) -> some View {
        HStack(spacing: 10) {
            Label("저장되지 않은 이전 작성본이 있습니다", systemImage: "arrow.counterclockwise")
                .font(.caption)
            Spacer(minLength: 4)
            Button("복구") {
                draft = saved.body
                title = saved.title
                typeID = saved.typeID
                bookID = saved.bookID
                notebookIDs = NotebookMembershipCore.normalized(primary: saved.bookID,
                    ids: saved.notebookIDs ?? (saved.bookID.isEmpty ? [] : [saved.bookID]))
                noteDay = WorkOSDate.parseDay(saved.noteDay)
                noteStatus = saved.status
                sourceURL = saved.sourceURL
                pinned = saved.pinned
                bodyEdited = true
                model.editorCaretOffsets[note.id] = (saved.body as NSString).length
                editorSession = UUID() // explicit recovery only; ordinary edits retain undo
                recoveryDraft = nil
                scheduleSave()
                schedulePreview()
            }
            Button("버리기") {
                recoveryDraft = nil
                Task { await MemoWeaverDraftRecoveryStore.shared.remove(noteID: note.id) }
            }
        }
        .padding(8)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
    }

    private func scheduleSave() {
        isDirty = true
        saveLabel = "저장 대기 중…"
        scheduleRecoveryWrite()
        pendingSave?.cancel()
        pendingSave = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if !Task.isCancelled { flush(checkpoint: false) }
        }
    }

    private func flush(checkpoint: Bool) {
        // Restoring a database changes the storage generation. An old editor
        // may still receive a delayed save or terminate notification before
        // SwiftUI finishes tearing it down. Never write that old draft back.
        guard mountGeneration == nil || mountGeneration == model.dataGeneration else {
            pendingSave?.cancel()
            return
        }
        pendingSave?.cancel()
        guard isDirty || checkpoint else { return } // simply viewing a legacy note NEVER migrates it
        let migrating = !note.isMarkdown && bodyEdited
        let okay = model.saveNote(note.id, title: title,
                                  bodyHTML: (note.isMarkdown || bodyEdited) ? draft : nil,
                                  typeID: typeID, bookID: bookID, noteDate: WorkOSDate.day(noteDay),
                                  status: noteStatus, sourceURL: sourceURL, pinned: pinned,
                                  archived: false, checkpoint: checkpoint,
                                  convertLegacyBodyToMarkdown: migrating,
                                  notebookIDs: notebookIDs)
        if okay {
            isDirty = false
            bodyEdited = false
            pendingRecoveryWrite?.cancel()
            pendingRecoveryWrite = nil
            Task { await MemoWeaverDraftRecoveryStore.shared.remove(noteID: note.id) }
            saveLabel = migrating || note.isMarkdown ? "모든 변경사항 저장됨" : "기존 HTML 원본 유지됨"
        } else {
            saveLabel = "저장 실패"
            // A failed SQLite flush cannot rely on a timer or onDisappear:
            // persist the most recent local draft before returning control.
            pendingRecoveryWrite?.cancel()
            do {
                try MemoWeaverDraftRecoveryStore.emergencyWrite(recoverySnapshot())
                model.statusMessage = "메모 저장 실패 · 작성본을 복구 파일에 보관했습니다"
            } catch {
                model.alertText = "메모와 임시 작성본 모두 저장하지 못했습니다. 내용을 복사해 다른 위치에 보관하세요. 원인: " + error.localizedDescription
            }
        }
    }

    private func schedulePreview(immediate: Bool = false) {
        guard previewActive else { return }
        pendingPreview?.cancel()
        previewRevision += 1
        let token = previewRevision
        let now = Date.timeIntervalSinceReferenceDate
        // Coalesce quick keystrokes, but NEVER postpone forever during long
        // typing bursts. The first change starts a capped 400ms window.
        let firstChange = immediate ? now : (pendingPreviewFirstChangeAt ?? now)
        pendingPreviewFirstChangeAt = firstChange
        let delay = immediate ? 0 : MemoWeaverPreviewPolicy.delay(
            firstChangeAt: firstChange, now: now)
        let source = draft
        let sourceTitle = title
        let day = WorkOSDate.day(noteDay)
        let sourceStatus = noteStatus
        let mode = MarkdownPreviewMode(rawValue: previewModeRaw) ?? .memo
        pendingPreview = Task { @MainActor in
            if delay > 0 {
                do { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
                catch { return }
            }
            guard !Task.isCancelled, token == previewRevision else { return }
            pendingPreviewFirstChangeAt = nil
            // Conversions run off-main, serially, and a superseded queued
            // request is skipped before it starts. Do not mutate draft here.
            guard let html = await MemoWeaverPreviewRenderer.shared.render(
                title: sourceTitle, noteDate: day, status: sourceStatus,
                markdown: source, mode: mode) else { return }
            guard !Task.isCancelled, token == previewRevision, previewActive else { return }
            if previewHTML != html { previewHTML = html }
        }
    }

    private func refreshPreview() {
        guard previewActive else { return }
        pendingPreviewFirstChangeAt = nil
        schedulePreview(immediate: true)
    }

    private func export(_ format: WorkOSNoteExport.Format) {
        flush(checkpoint: false)
        guard saveLabel != "저장 실패", let current = model.notes.first(where: { $0.id == note.id }) else { return }
        WorkOSNoteExport.export(current, format: format) { result in
            switch result {
            case .success(let url): model.statusMessage = "내보내기 완료: \(url.lastPathComponent)"
            case .failure(let error): model.alertText = "내보내기 실패: \(error.localizedDescription)"
            }
        }
    }

    private func addProgress() {
        flush(checkpoint: false)
        if saveLabel != "저장 실패" {
            model.addProgress(noteID: note.id, text: progressText)
            progressText = ""
        }
    }
}


// Contextual block tools occupy the SAME 30pt third row as the regular
// Markdown toolbar. A horizontal ScrollView cut off LaTeX buttons above and
// below the row on macOS. Keep one natural-height row, with ViewThatFits:
// quick actions + grouped menus => group menus => one complete overflow menu.
// No command is lost when the editor narrows or the auxiliary pane opens.
private struct MarkdownAssistPalette: View {
    let context: MarkdownEditingContext
    let onInsert: (MarkdownAssistSnippet) -> Void
    let onInsertAdvanced: (MemoWeaverSourceTemplate) -> Void

    private var title: String {
        switch context {
        case .math: return "LaTeX"
        case .mermaid: return "순서도"
        case .mermaidXY: return "XY 차트"
        case .mermaidPie: return "원형 차트"
        case .mermaidGantt: return "Gantt"
        case .mermaidTimeline: return "Timeline"
        case .mermaidSequence: return "Sequence"
        case .mermaidClass: return "Class"
        case .mermaidState: return "State"
        case .mermaidER: return "ER"
        case .mermaidGit: return "Git"
        case .mermaidJourney: return "Journey"
        case .mermaidQuadrant: return "사분면"
        case .markmap: return "마인드맵"
        default: return "Markdown"
        }
    }

    private var currentGroups: [MarkdownAssistGroup] {
        MarkdownAssistGroup.allCases.filter { $0.context == context }
    }

    private var quickSnippets: [MarkdownAssistSnippet] {
        switch context {
        case .math: return [.fraction, .squareRoot, .gatheredEquations, .alignedEquations]
        case .mermaid: return [.node, .connection]
        case .mermaidXY: return [.xyXAxis, .xyBar]
        case .mermaidPie: return [.pieSlice]
        case .mermaidGantt: return [.ganttTask]
        case .mermaidTimeline: return [.timelineEvent]
        case .mermaidSequence: return [.sequenceMessage]
        case .markmap: return [.markmapHeading, .markmapChild]
        default: return []
        }
    }

    @State private var groupSymbolsVisible = false
    @State private var overflowSymbolsVisible = false

    // The compact native Menu rendered LaTeX glyphs at tiny system-menu size.
    // The enlarged grid keeps every command but does not add a toolbar row.
    private func snippetButtons(in group: MarkdownAssistGroup) -> some View {
        snippetItems(MarkdownAssistSnippet.allCases.filter { $0.group == group })
    }

    private func snippetItems(_ snippets: [MarkdownAssistSnippet]) -> some View {
        ForEach(snippets, id: \.self) { snippet in
            Button(snippet.title) { onInsert(snippet) }
                .memoTooltip(snippet.help)
        }
    }

    private func quickSymbol(_ snippet: MarkdownAssistSnippet) -> String {
        switch snippet {
        case .fraction: return "divide"
        case .squareRoot: return "x.squareroot"
        case .superscript: return "textformat.superscript"
        case .gatheredEquations: return "text.aligncenter"
        case .alignedEquations: return "text.alignleft"
        case .node: return "square"
        case .connection: return "arrow.right"
        case .xyXAxis: return "arrow.right"
        case .xyBar: return "chart.bar"
        case .pieSlice: return "chart.pie"
        case .ganttTask: return "calendar"
        case .timelineEvent: return "clock"
        case .sequenceMessage: return "bubble.left"
        case .markmapHeading: return "textformat.size"
        case .markmapChild: return "arrow.turn.down.right"
        default: return "plus"
        }
    }

    private var groupedMenus: some View {
        ForEach(currentGroups, id: \.self) { group in
            if group == .mathSymbols {
                Button { groupSymbolsVisible = true } label: {
                    Image(systemName: group.symbol)
                        .frame(minWidth: 23, minHeight: 22)
                        .accessibilityLabel("기호 크게 보기")
                }
                .modifier(MemoWeaverHeaderIconSurface(height: 26))
                .fixedSize(horizontal: true, vertical: false)
                .memoTooltip("수학 기호 · 크게 보기")
                .popover(isPresented: $groupSymbolsVisible,
                         attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                    MemoWeaverMathSymbolPicker { snippet in
                        groupSymbolsVisible = false
                        onInsert(snippet)
                    }
                }
            } else {
                Menu { snippetButtons(in: group) } label: {
                    Image(systemName: group.symbol)
                        .frame(minWidth: 23, minHeight: 22)
                        .accessibilityLabel(group.title)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .modifier(MemoWeaverHeaderIconSurface(height: 26))
                .fixedSize(horizontal: true, vertical: false)
                .memoTooltip("\(title) · \(group.title) 도구")
            }
        }
    }

    private var additionalContextMenu: some View {
        Menu {
            ForEach(MemoWeaverDiagramExtraTools.items(for: context)) { item in
                Button(item.title) { onInsertAdvanced(item) }
            }
        } label: {
            Image(systemName: "plus.square.on.square")
                .frame(minWidth: 24, minHeight: 22)
                .accessibilityLabel(title + " 추가 템플릿")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .modifier(MemoWeaverHeaderIconSurface(height: 26))
        .fixedSize(horizontal: true, vertical: false)
        .memoTooltip(title + " 추가 템플릿")
    }

    private var allToolsMenu: some View {
        Menu {
            ForEach(currentGroups, id: \.self) { group in
                if group == .mathSymbols {
                    Button("기호 크게 보기…") {
                        DispatchQueue.main.async { overflowSymbolsVisible = true }
                    }
                } else {
                    Menu(group.title) { snippetButtons(in: group) }
                }
            }
            ForEach(MemoWeaverDiagramExtraTools.items(for: context)) { item in
                Button(item.title) { onInsertAdvanced(item) }
            }
        } label: {
            Image(systemName: context == .math ? "function" : "square.grid.2x2")
                .frame(minWidth: 24, minHeight: 22)
                .accessibilityLabel(title + " 도구 전체")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .modifier(MemoWeaverHeaderIconSurface(height: 26))
        .fixedSize(horizontal: true, vertical: false)
        .memoTooltip("\(title) 블록 편집 도구 전체")
        .popover(isPresented: $overflowSymbolsVisible,
                 attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
            MemoWeaverMathSymbolPicker { snippet in
                overflowSymbolsVisible = false
                onInsert(snippet)
            }
        }
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 5) {
                Image(systemName: context == .math ? "function" :
                                    (context == .markmap ? "brain.head.profile" : "arrow.triangle.branch"))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(title)
                ForEach(quickSnippets, id: \.self) { snippet in
                    Button { onInsert(snippet) } label: {
                        Image(systemName: quickSymbol(snippet))
                            .frame(minWidth: 24, minHeight: 22)
                    }
                    .modifier(MemoWeaverHeaderIconSurface(height: 26))
                    .memoTooltip(snippet.title + " · " + snippet.help)
                    .accessibilityLabel(snippet.title)
                    .fixedSize(horizontal: true, vertical: false)
                }
                groupedMenus
                if !MemoWeaverDiagramExtraTools.items(for: context).isEmpty { additionalContextMenu }
            }
            .fixedSize(horizontal: true, vertical: false)
            HStack(spacing: 5) {
                Image(systemName: context == .math ? "function" :
                                    (context == .markmap ? "brain.head.profile" : "arrow.triangle.branch"))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(title)
                groupedMenus
                if !MemoWeaverDiagramExtraTools.items(for: context).isEmpty { additionalContextMenu }
            }
            .fixedSize(horizontal: true, vertical: false)
            allToolsMenu
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 30, alignment: .center)
        // Context palette uses the same readable control metrics as Markdown.
        .font(.system(size: 13, weight: .medium))
        .buttonStyle(.plain)
        .controlSize(.small)
        .accessibilityLabel(title + " 블록 편집 도구")
    }
}
