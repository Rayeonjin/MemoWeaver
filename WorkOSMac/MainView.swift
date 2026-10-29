import AppKit
import Combine
import SwiftUI

// The editor reports a failed SQLite flush here. A layout swap is skipped
// rather than remounting an editor with unsaved content.
final class MemoWeaverLayoutCommitRequest {
    var canProceed = true
}

enum MemoWeaverLayoutSwitchSafety {
    static func prepare() -> Bool {
        // A Korean IME marked-text sequence is not a committed text change.
        // Do not recreate NSTextView while it is still composing.
        if let editor = NSApp.keyWindow?.firstResponder as? NSTextView,
           editor.hasMarkedText() { return false }
        let request = MemoWeaverLayoutCommitRequest()
        NotificationCenter.default.post(name: .memoWeaverBeforeLayoutChange, object: request)
        return request.canProceed
    }
}

struct WorkOSMainView: View {
    @EnvironmentObject private var model: WorkOSModel
    // One toolbar control owns one right panel. Tabs only change its content.
    // Persist explicit open/closed choices; only the untouched "automatic" state
    // uses the note's default preview visibility.
    @AppStorage("memoweaver.rightPane.visibility") private var paneVisibilityPreference = "automatic"
    @AppStorage("memoweaver.rightPane.activeTab") private var rightPaneTabRaw = "preview"
    // One permanent activity-rail navigation. The old compact/legacy shell
    // switch was redundant with the explicit, reversible focus mode.
    @State private var livePreviewHTML = ""
    @State private var livePreviewCaretLine = 1
    @State private var livePreviewNoteID: String?
    @State private var showQuickSearch = false
    @State private var quickSearchInitialQuery = ""
    @State private var focusModeEnabled = false
    @AppStorage(MemoryIdlePolicy.defaultsKey) private var backgroundMode = "automatic"
    @AppStorage("memoryhome.typography.fontSize") private var editorFontSize = EditorTypographyRules.defaultSize
    @AppStorage("memoryhome.typography.lineHeight") private var editorLineHeight = EditorTypographyRules.defaultLineHeight
    @State private var referenceFilter = ""
    // Persistent, user-controlled list. No automatic breakpoint/popover.
    @AppStorage("memoweaver.notes.listVisible") private var noteListVisible = true
    @AppStorage("memoweaver.notes.preferredWidth") private var preferredListWidth = 0.0
    @AppStorage("memoweaver.rightPane.preferredWidth") private var preferredRightWidth = 0.0
    // A unique one-shot request lets AppKit adjust the existing split divider
    // without disturbing the mounted editor, cursor or saved note-list width.
    @State private var rightPaneRatioRequest: MemoWeaverPaneRatioRequest?
    // Actual proportion from AppKit, not a saved preset that may differ after
    // resize or manual dragging. Presentation-only: no SQLite changes.
    @State private var currentEditorRatioPercent: Int? = nil

    var body: some View {
        compactShell
        .alert("MemoWeaver", isPresented: Binding(
            get: { model.alertText != nil },
            set: { if !$0 { model.alertText = nil } }
        )) {
            Button("확인", role: .cancel) { model.alertText = nil }
        } message: {
            Text(model.alertText ?? "")
        }
        .task {
            // Backup maintenance only. Do not ping Ollama or start embeddings on launch.
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 3_600_000_000_000) }
                catch { break }
                if !Task.isCancelled { model.backupIfNeeded() }
            }
        }
        // Native transient popover: clicking outside closes it. A modal sheet
        // previously trapped clicks until Escape was pressed.
        .popover(isPresented: $showQuickSearch, arrowEdge: .top) {
            MemoWeaverQuickSearchPalette(initialQuery: quickSearchInitialQuery,
                                         onToggleFocus: toggleFocusMode)
                .environmentObject(model)
        }
        .onReceive(NotificationCenter.default.publisher(for: .memoWeaverOpenQuickSearch)) { notice in
            quickSearchInitialQuery = notice.userInfo?["query"] as? String ?? ""
            showQuickSearch = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .memoWeaverCreateNewNote)) { _ in
            model.newNoteFromShortcut()
        }
        .onReceive(NotificationCenter.default.publisher(for: .memoWeaverSelectRightPaneTab)) { notice in
            guard isNotePage && model.currentNote != nil,
                  let raw = notice.userInfo?["tab"] as? String,
                  let tab = NoteSidePaneTab(rawValue: raw) else { return }
            if focusModeEnabled {
                toggleFocusMode()
                guard !focusModeEnabled else { return }
            }
            selectRightPaneTab(tab)
            setSidePaneVisible(true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .memoWeaverToggleFocusMode)) { _ in
            toggleFocusMode()
        }
        .onReceive(NotificationCenter.default.publisher(for: .memoWeaverToggleNoteList)) { _ in
            if isNotePage {
                toggleNoteList()
            } else {
                // The native sidebar action must never become a dead button
                // on Settings, Planner, Search or the Memory screens.
                openRailPage(.all)
                noteListVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .memoWeaverToggleRightPane)) { _ in
            guard isNotePage && model.currentNote != nil else { return }
            if focusModeEnabled {
                // Keep a permanent right-pane toolbar action even in focus.
                // Returning to the regular workspace must respect IME/save guards.
                toggleFocusMode()
                if !focusModeEnabled { setSidePaneVisible(true) }
            } else {
                setSidePaneVisible(!sidePaneVisible)
            }
        }
        .onAppear {
            // Build the incremental catch-up queue only; NO Ollama ping or
            // embeddings happen until the idle policy permits work.
            model.requestBackgroundCorpusIndex()
            // A clicked notification can launch a new WorkOS process.
            if let id = UserDefaults.standard.string(forKey: "workos.reminder.pendingOpenID") {
                UserDefaults.standard.removeObject(forKey: "workos.reminder.pendingOpenID")
                model.openSchedule(id)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .workosReminderOpened)) { notice in
            if let id = notice.userInfo?["itemID"] as? String {
                UserDefaults.standard.removeObject(forKey: "workos.reminder.pendingOpenID")
                model.openSchedule(id)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            model.appMovedToBackground()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.appDidReturnToForeground()
            model.checkReminderPermission()
            model.backupIfNeeded()
        }
        .onChange(of: model.selectedNoteID) { _, nextID in
            if let nextID, model.selectedPage.isActiveNotesPage,
               model.notes.contains(where: { $0.id == nextID && $0.deletedAt.isEmpty }) {
                UserDefaults.standard.set(nextID, forKey: "memoweaver.notes.lastOpenedID")
            }
            livePreviewCaretLine = 1
            // Never undo the user's explicit close (or open) on note selection.
            // Only the untouched automatic mode defaults to the preview tab.
            // Preserve the selected auxiliary workflow; preview/search does not
            // retake focus just because a new note was opened.
            // Do not clear a preview rendered by the incoming editor's onAppear;
            // the note ID prevents showing a previous note's HTML while switching.
        }
        .onChange(of: model.selectedPage) { newPage in
            if !isNotePage { focusModeEnabled = false }
            // A navigation tap must not discard the user's notebook/type filters.
            if newPage == .memory { model.regenerateMemoryGraph() }
            // These screens are explicit user requests. Ollama is not called on app launch.
            if newPage == .assistant || newPage == .memory {
                model.loadMemoryCache()
                if !model.aiConnected && !model.isCheckingAI {
                    Task { await model.checkAI() }
                }
            }
            // Automatic AI scheduling is independent of sidebar navigation.
            // Page transitions never directly run Ollama on the UI thread.
            if newPage == .trash {
                // Trash is a deliberate navigation action, not a list filter.
                model.selectedNoteID = model.filteredNotes.first?.id
            } else if isNotePage {
                model.selectVisibleNoteAfterFiltering()
            }
        }
    }

    // Actual macOS NSToolbar: left and right actions track the NSSplitView
    // sections, even when one or both side panes are closed.
    private var nativeToolbarSnapshot: MemoWeaverToolbarSnapshot {
        let note = model.currentNote
        let visibleNote: Bool
        if isNotePage, let note {
            visibleNote = model.selectedPage == .trash
                ? !note.deletedAt.isEmpty : note.deletedAt.isEmpty
        } else {
            visibleNote = false
        }
        return MemoWeaverToolbarSnapshot(
            isNotePage: isNotePage,
            listVisible: effectiveListVisible,
            rightVisible: effectiveRightPaneVisible,
            focusMode: focusModeEnabled,
            hasCurrentNote: visibleNote,
            noteID: visibleNote ? (note?.id ?? "") : "",
            noteTitle: visibleNote ? (note?.title ?? "") : "",
            notePinned: visibleNote && (note?.pinned ?? false),
            noteTrashed: visibleNote && !(note?.deletedAt.isEmpty ?? true),
            isTrashPage: model.selectedPage == .trash,
            selectedRightTab: rightPaneTab.rawValue)
    }

    // Compact mode is a fixed activity rail beside the EXISTING notes split.
    // No auto-collapse, intermediate popover, new database or editor rework.
    private var compactShell: some View {
        HStack(spacing: 0) {
            if !focusModeEnabled {
                activityRail
                    .zIndex(20) // Hover labels float over the workspace.
                Divider()
            }
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // NSSplitView starts below the ACTUAL one-row native titlebar.
        // Only list/editor and editor/auxiliary divider color and X positions
        // extend into the titlebar; no rail separator is painted above content.
        .background(Color(nsColor: .windowBackgroundColor))
        .background(MemoWeaverNativeWindowChrome(snapshot: nativeToolbarSnapshot)
            .frame(width: 1, height: 1).allowsHitTesting(false))
    }

    // Activity bar is visible in regular mode and hidden in focus mode.
    // Changing route replaces
    // the central content, NOT another independently opening side panel.
    private var activityRail: some View {
        VStack(spacing: 3) {
            VStack(spacing: 3) {
                railButton(.all, title: "메모", symbol: "note.text")
                railButton(.search, title: "빠른 검색 · ⌘K", symbol: "magnifyingglass")
            }
            .padding(.top, 9)
            .frame(width: 52, height: MemoWeaverWorkspaceHeaderMetrics.height,
                   alignment: .top)
            railButton(.today, title: "업무일지", symbol: "calendar")
            railButton(.planner, title: "일정", symbol: "calendar.badge.clock")
            railButton(.memory, title: "기억 지도", symbol: "point.3.connected.trianglepath.dotted")
            Spacer(minLength: 6)
            railButton(.settings, title: "설정", symbol: "gearshape")
        }
        // Only the section boundaries separate panes: no horizontal ornaments
        // inside the activity rail. Native titlebar renders the traffic lights;
        // keep the rail background
        // the same as the window instead of a conflicting control-gray strip.
        .padding(.bottom, 7)
        .frame(width: 52)
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func railIsSelected(_ page: WorkspacePage) -> Bool {
        if page == .all { return model.selectedPage.isActiveNotesPage }
        return model.selectedPage == page
    }

    private func openRailPage(_ page: WorkspacePage) {
        if page == .search {
            showQuickSearch = true
            return
        }
        // Only a deliberate visit to the notes/trash route reveals the list.
        // Window resizing and switching to other pages never toggle it.
        if page == .all || page == .trash { noteListVisible = true }
        model.selectedPage = page
    }

    private func railButton(_ page: WorkspacePage, title: String, symbol: String) -> some View {
        let selected = railIsSelected(page)
        return Button { openRailPage(page) } label: {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: selected ? .semibold : .regular))
                .frame(width: 40, height: 38)
                .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                .background(selected ? Color.accentColor.opacity(0.14) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .memoTooltip(title)
        .accessibilityLabel(title)
        .accessibilityValue(selected ? "선택됨" : "선택되지 않음")
    }

    // Reserve the necessary WINDOW width before SwiftUI updates panel
    // visibility; otherwise NSSplitView briefly compresses a remembered pane
    // and the toolbar can hide controls. User-set pane widths are not changed.
    private func reserveWindowForPaneOpening(list: Bool, right: Bool) {
        MemoWeaverPaneWindowSizing.expandForPaneOpening(
            listVisible: list, rightVisible: right, focusMode: false,
            preferredListWidth: CGFloat(preferredListWidth),
            preferredRightWidth: CGFloat(preferredRightWidth))
    }

    private func toggleFocusMode() {
        guard isNotePage else { return }
        guard MemoWeaverLayoutSwitchSafety.prepare() else {
            model.alertText = "입력 조합 또는 저장이 완료되지 않아 화면을 유지합니다. 먼저 입력을 확정해 주세요."
            return
        }
        // The user's saved visibility preferences are NEVER overwritten.
        // Returning from focus restores the exact previous pane choices.
        // Make space BEFORE both remembered panes are reinserted.
        if focusModeEnabled {
            reserveWindowForPaneOpening(list: noteListVisible, right: sidePaneVisible)
        }
        focusModeEnabled.toggle()
    }

    private var isNotePage: Bool {
        switch model.selectedPage {
        case .all, .kind, .trash: return true
        default: return false
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch model.selectedPage {
        case .archives: ArchiveScreen()
        case .today: WorkOSDailyJournalScreen()
        case .planner: WorkOSPlannerScreen()
        case .search: GlobalRecallSearchScreen()
        case .assistant: AssistantScreen()
        case .memory: MemoryMapScreen()
        case .settings: SettingsScreen()
        default: notesWorkspace
        }
    }

    private var rightPaneTab: NoteSidePaneTab {
        NoteSidePaneTab(rawValue: rightPaneTabRaw) ?? .preview
    }

    private func selectRightPaneTab(_ tab: NoteSidePaneTab) {
        rightPaneTabRaw = tab.rawValue
    }

    private func setSidePaneVisible(_ visible: Bool) {
        if visible && !effectiveRightPaneVisible && !focusModeEnabled {
            reserveWindowForPaneOpening(list: effectiveListVisible, right: true)
        }
        paneVisibilityPreference = visible ? "open" : "closed"
    }

    private var sidePaneVisible: Bool {
        guard isNotePage, let note = model.currentNote else { return false }
        if model.selectedPage == .trash && note.deletedAt.isEmpty { return false }
        return NoteSidePaneRules.isVisibleForLayout(
            preference: paneVisibilityPreference, compactNavigation: true,
            tab: rightPaneTab, bodyHTML: note.bodyHTML,
            blocks: note.workosBlocks, isMarkdown: note.isMarkdown)
    }

    private var effectiveListVisible: Bool { noteListVisible && !focusModeEnabled }
    private var effectiveRightPaneVisible: Bool { sidePaneVisible && !focusModeEnabled }

    // AppKit owns both native dividers. Window resizing and panel toggling
    // retain the user's last list/auxiliary widths; the editor takes the delta.
    // There is no GeometryReader-driven ideal-width redistribution.
    private var notesWorkspace: some View {
        MemoWeaverPinnedSplitView(
            list: NotesNavigationListView().environmentObject(model)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).clipped(),
            editor: activeNoteEditor.environmentObject(model)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).clipped(),
            right: activeRightPane.environmentObject(model)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).clipped(),
            listVisible: effectiveListVisible,
            rightVisible: effectiveRightPaneVisible,
            listPreferred: CGFloat(preferredListWidth),
            rightPreferred: CGFloat(preferredRightWidth),
            saveListWidth: { preferredListWidth = Double($0) },
            saveRightWidth: { preferredRightWidth = Double($0) },
            onRatioMeasured: { percent in
                if currentEditorRatioPercent != percent { currentEditorRatioPercent = percent }
            },
            ratioRequest: rightPaneRatioRequest)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func toggleNoteList() {
        if focusModeEnabled {
            // The list button is still visible beside the title in focus
            // mode. Exit focus safely before revealing the list; never
            // change the saved visibility while focus is active.
            toggleFocusMode()
            if !focusModeEnabled {
                if !noteListVisible {
                    reserveWindowForPaneOpening(list: true, right: effectiveRightPaneVisible)
                }
                noteListVisible = true
            }
        } else {
            if !noteListVisible {
                reserveWindowForPaneOpening(list: true, right: effectiveRightPaneVisible)
            }
            noteListVisible.toggle()
        }
    }

    @ViewBuilder
    private var activeNoteEditor: some View {
        // A search/filter must never destroy or replace the active editor.
        if let note = model.currentNote,
           (model.selectedPage == .trash ? !note.deletedAt.isEmpty : note.deletedAt.isEmpty) {
            // A single editor for legacy and new notes; never rewrite source here.
            MarkdownNoteEditorScreen(
                note: note,
                listPaneVisible: effectiveListVisible,
                auxiliaryPaneVisible: effectiveRightPaneVisible,
                focusMode: focusModeEnabled,
                previewActive: effectiveRightPaneVisible && rightPaneTab == .preview,
                previewHTML: Binding(
                    get: { livePreviewNoteID == note.id ? livePreviewHTML : "" },
                    set: { html in
                        guard model.selectedNoteID == note.id else { return }
                        livePreviewNoteID = note.id
                        livePreviewHTML = html
                    }),
                previewCaretLine: $livePreviewCaretLine,
                openPreview: {
                    selectRightPaneTab(.preview)
                    setSidePaneVisible(true)
                })
                .id(note.id + ":" + model.dataGeneration.uuidString)
        } else {
            // The titlebar always retains list restore + new note, including
            // an empty selection. Keep the editor body a genuine empty state.
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                ContentUnavailableView("메모를 선택하세요", systemImage: "square.and.pencil",
                    description: Text("새 메모를 작성하거나 왼쪽에서 기존 기록을 열어 보세요."))
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func applyRightPaneRatio(_ preset: MemoWeaverPaneRatioPreset) {
        guard effectiveRightPaneVisible else { return }
        rightPaneRatioRequest = MemoWeaverPaneRatioRequest(id: UUID(), preset: preset)
    }

    private var activeRightPane: some View {
        WorkOSUnifiedRightPane(
            selectedTab: Binding(
                get: { rightPaneTab },
                set: { next in
                    selectRightPaneTab(next)
                    setSidePaneVisible(true)
                }),
            previewHTML: livePreviewNoteID == model.selectedNoteID ? livePreviewHTML : "",
            previewCaretLine: livePreviewCaretLine,
            currentNoteID: model.selectedNoteID ?? "",
            referenceFilter: $referenceFilter,
            editorRatioPercent: currentEditorRatioPercent,
            onApplyRatio: applyRightPaneRatio)
    }



}


// One note list; the filters change only visibility, never which SQLite table is used.
private struct NotesNavigationListView: View {
    @EnvironmentObject private var model: WorkOSModel
    @AppStorage("memoweaver.notes.compactRows") private var compactRows = false
    // Retain the local list search when the user visits global search and
    // returns; the text is distinct from the global/reference query.
    @AppStorage("memoweaver.notes.quickQuery") private var listQuery = ""
    @State private var showingNewBook = false
    @State private var showingNewType = false
    @State private var pendingTrashNote: WorkNote?

    private var displayedNotes: [WorkNote] {
        let term = listQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return model.filteredNotes }
        return model.filteredNotes.filter { note in
            // Fast local-list search. For deep archive/virtual search, use 전체 검색.
            note.visibleTitle.localizedStandardContains(term) ||
                String(note.plainBody.prefix(1600)).localizedStandardContains(term)
        }
    }

    private var outsideFilter: Bool {
        guard let note = model.currentNote, note.deletedAt.isEmpty,
              model.selectedPage.isActiveNotesPage else { return false }
        return !displayedNotes.contains(where: { $0.id == note.id })
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                filteringControls
                Spacer(minLength: 0)
            }
            .frame(height: MemoWeaverWorkspaceHeaderMetrics.height, alignment: .top)
            Divider()
            if outsideFilter { outsideFilterHint }
            List(selection: $model.selectedNoteID) {
                ForEach(displayedNotes) { note in
                    NoteListRow(note: note, typeName: model.typeName(note.typeID),
                                bookNames: model.notebookNames(for: note),
                                compact: compactRows)
                        .tag(note.id)
                        .contextMenu {
                            if note.deletedAt.isEmpty {
                                Button("휴지통으로 이동…", systemImage: "trash", role: .destructive) {
                                    pendingTrashNote = note
                                }
                            } else {
                                Button("메모 복원", systemImage: "arrow.uturn.backward") {
                                    guard safeToChangeNote() else { return }
                                    if let latest = model.notes.first(where: { $0.id == note.id }) {
                                        model.markDeleted(latest, deleted: false)
                                    }
                                }
                            }
                        }
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            Divider()
            listFooter
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .confirmationDialog("이 메모를 휴지통으로 이동하시겠습니까?",
                            isPresented: Binding(get: { pendingTrashNote != nil },
                                set: { if !$0 { pendingTrashNote = nil } })) {
            Button("휴지통으로 이동", role: .destructive) {
                guard let candidate = pendingTrashNote else { return }
                pendingTrashNote = nil
                guard safeToChangeNote() else { return }
                // Use the freshest note after the editor committed pending
                // changes, never the stale row value captured by the menu.
                if let latest = model.notes.first(where: { $0.id == candidate.id && $0.deletedAt.isEmpty }) {
                    model.markDeleted(latest, deleted: true)
                }
            }
            Button("취소", role: .cancel) { pendingTrashNote = nil }
        } message: {
            Text("휴지통에서 복원할 수 있습니다. 작성 중인 변경사항은 먼저 저장합니다.")
        }
    }

    private func safeToChangeNote() -> Bool {
        guard MemoWeaverLayoutSwitchSafety.prepare() else {
            model.alertText = "한글 조합이 진행 중이거나 메모 저장에 실패하여 작업을 취소했습니다. 입력과 저장 상태를 확인해 주세요."
            return false
        }
        return true
    }

    // Count lives here, rather than repeating the header count. Filter state
    // and count stay visible while the list scrolls; no changing row height.
    private var listFooter: some View {
        MemoWeaverPaneFooter {
            Text(model.selectedPage == .trash ? "휴지통" : model.notesScope.title)
                .fontWeight(.medium)
                .lineLimit(1)
            if !listQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
               !model.selectedBookFilterID.isEmpty || !model.selectedTypeFilterID.isEmpty {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .memoTooltip("검색 또는 분류 필터 적용 중")
            }
            Spacer(minLength: 2)
            // The former titlebar '…' menu has only two actions. Surface
            // both directly in the stable list footer instead of a submenu.
            Button { compactRows.toggle() } label: {
                Image(systemName: compactRows ? "rectangle.compress.vertical" : "text.alignleft")
                    .frame(width: 24, height: MemoWeaverPaneFooterMetrics.controlHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .modifier(MemoWeaverFooterControl(selected: compactRows))
            .memoTooltip(compactRows ? "일반 목록으로 전환" : "간결한 목록으로 전환")
            .accessibilityLabel("간결한 목록")
            .accessibilityValue(compactRows ? "켜짐" : "꺼짐")
            Text("\(displayedNotes.count)개")
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var filteringControls: some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("메모 목록에서 찾기", text: $listQuery)
                    .textFieldStyle(.plain)
                if !listQuery.isEmpty {
                    Button { listQuery = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }
                Button { model.selectedPage = .search } label: {
                    Image(systemName: "arrow.up.right.square")
                }
                .buttonStyle(.plain)
                .memoTooltip("모든 기록 검색 · 일반 메모 / 과거 TXT / 긴 메모")
            }
            .font(.system(size: 12))
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
            .frame(height: 30)
            Picker("보기", selection: $model.notesScope) {
                ForEach(NotesListScope.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .disabled(model.selectedPage == .trash)
            .labelsHidden()
            .frame(height: 30)
            HStack(spacing: 6) {
                bookFilter.frame(minWidth: 0, maxWidth: .infinity)
                typeFilter.frame(minWidth: 0, maxWidth: .infinity)
                Button {
                    guard safeToChangeNote() else { return }
                    model.selectedPage = model.selectedPage == .trash ? .all : .trash
                } label: {
                    Image(systemName: model.selectedPage == .trash ? "trash.fill" : "trash")
                        .font(.system(size: 13))
                        .frame(width: 27, height: 27)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(model.selectedPage == .trash ? Color.accentColor : Color.secondary)
                .background(model.selectedPage == .trash ? Color.accentColor.opacity(0.12) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 5))
                .memoTooltip(model.selectedPage == .trash ? "모든 메모로 돌아가기" : "휴지통 열기")
                .accessibilityLabel("휴지통")
                if !model.selectedBookFilterID.isEmpty || !model.selectedTypeFilterID.isEmpty {
                    Button { model.resetNoteFilters() } label: {
                        Image(systemName: "xmark.circle")
                            .frame(width: 23, height: 27)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .memoTooltip("노트북·종류 필터 초기화")
                    .accessibilityLabel("분류 필터 초기화")
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 30)
        }
        .padding(.horizontal, 12).padding(.vertical, 4)
        // Filters change the list, never the active editor selection.
    }

    // The list can be 175pt wide. Filters share only the AVAILABLE width;
    // no oversized intrinsic Menu label is allowed to paint over the editor.
    private var bookFilter: some View {
        Menu {
            Button {
                model.selectedBookFilterID = ""
            } label: {
                if model.selectedBookFilterID.isEmpty { Label("전체 노트북", systemImage: "checkmark") }
                else { Text("전체 노트북") }
            }
            ForEach(model.books) { book in
                Button {
                    model.selectedPage = .all
                    model.selectedBookFilterID = book.id
                } label: {
                    if model.selectedBookFilterID == book.id { Label(book.name, systemImage: "checkmark") }
                    else { Text(book.name) }
                }
            }
            Divider()
            Button("새 노트북 만들기…", systemImage: "plus") { showingNewBook = true }
        } label: {
            listFilterLabel(model.selectedBookFilterID.isEmpty ? "노트북" : model.bookName(model.selectedBookFilterID),
                            symbol: "folder")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(minWidth: 0, maxWidth: .infinity)
        .sheet(isPresented: $showingNewBook) {
            MemoWeaverCategoryCreationSheet(kind: "book") { id in
                model.selectedBookFilterID = id
            }.environmentObject(model)
        }
    }

    private var typeFilter: some View {
        Menu {
            Button {
                model.selectedTypeFilterID = ""
            } label: {
                if model.selectedTypeFilterID.isEmpty { Label("전체 종류", systemImage: "checkmark") }
                else { Text("전체 종류") }
            }
            ForEach(model.types) { item in
                Button {
                    model.selectedPage = .all
                    model.selectedTypeFilterID = item.id
                } label: {
                    if model.selectedTypeFilterID == item.id { Label(item.name, systemImage: "checkmark") }
                    else { Text(item.name) }
                }
            }
            Divider()
            Button("새 종류 만들기…", systemImage: "plus") { showingNewType = true }
        } label: {
            listFilterLabel(model.selectedTypeFilterID.isEmpty ? "종류" : model.typeName(model.selectedTypeFilterID),
                            symbol: "tag")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(minWidth: 0, maxWidth: .infinity)
        .sheet(isPresented: $showingNewType) {
            MemoWeaverCategoryCreationSheet(kind: "type") { id in
                model.selectedTypeFilterID = id
            }.environmentObject(model)
        }
    }

    private func listFilterLabel(_ text: String, symbol: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).foregroundStyle(.secondary)
            Text(text).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 0)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 6)
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(height: 27)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 0.7))
        .contentShape(Rectangle())
    }

    private var trashHelp: some View {
        Text("삭제한 메모를 선택해 복원할 수 있습니다.")
            .font(.caption2).foregroundStyle(.secondary)
            .padding(.horizontal, 12).padding(.bottom, 10)
    }

    private var outsideFilterHint: some View {
        HStack(spacing: 5) {
            Image(systemName: "line.3.horizontal.decrease.circle")
            Text("작성 중인 메모는 현재 목록 필터 밖에 있습니다.")
                .lineLimit(2)
        }
        .font(.caption2).foregroundStyle(.secondary)
        .padding(.horizontal, 12).padding(.vertical, 7)
    }
}

// The right-hand side is a SINGLE panel. Switching tabs keeps MarkdownNoteEditorScreen
// mounted, preventing the view change from reloading unsaved NSTextView content.
private struct WorkOSUnifiedRightPane: View {
    @AppStorage("memoweaver.preview.appearance") private var previewAppearance = "system"
    @AppStorage("memoweaver.preview.followCaret") private var followPreviewCaret = true
    @Binding var selectedTab: NoteSidePaneTab
    let previewHTML: String
    let previewCaretLine: Int
    let currentNoteID: String
    @Binding var referenceFilter: String
    let editorRatioPercent: Int?
    let onApplyRatio: (MemoWeaverPaneRatioPreset) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Preview/connection/reference tabs are in THIS pane's tracked
            // segment of the native toolbar, never a floating global group.
            Group {
                switch selectedTab {
                case .preview:
                    WorkOSSidePreviewPane(html: previewHTML,
                                          focusLine: followPreviewCaret ? previewCaretLine : 1)
                case .reference:
                    ReferenceWorkspacePane(currentNoteID: currentNoteID,
                                           caretLine: previewCaretLine, query: $referenceFilter)
                case .memory:
                    SideMemoryPane(noteID: currentNoteID, caretLine: previewCaretLine)
                case .assistant:
                    MemoWeaverSideAssistantPane(noteID: currentNoteID)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            auxiliaryFooter
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func paneTitle(_ tab: NoteSidePaneTab) -> String {
        switch tab {
        case .preview: return "미리보기"
        case .memory: return "연결"
        case .reference: return "참고 메모"
        case .assistant: return "AI 질문"
        }
    }

    private func sideTab(_ tab: NoteSidePaneTab, title: String,
                         symbol: String, compact: Bool) -> some View {
        Button { selectedTab = tab } label: {
            Group {
                if compact {
                    Image(systemName: symbol).frame(width: 34, height: 28)
                } else {
                    Label(title, systemImage: symbol)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 8)
                        .frame(height: 28)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(MemoWeaverHeaderIconSurface(selected: selectedTab == tab, height: 28))
        .memoTooltip(title, when: compact)
        .accessibilityLabel(title)
        .accessibilityValue(selectedTab == tab ? "선택됨" : "선택되지 않음")
    }

    // Flat 30pt bar shared with the editor and note list.
    // Preview-only controls are not misleadingly shown in the other two tabs.
    private var auxiliaryFooter: some View {
        MemoWeaverPaneFooter {
            ViewThatFits(in: .horizontal) {
                footerRow(showFollowCaret: true, truncateTitle: false)
                footerRow(showFollowCaret: false, truncateTitle: false)
                footerRow(showFollowCaret: false, truncateTitle: true)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // The tab title is always anchored to the LEFT. Only the optional
    // follow-caret action yields at the smallest supported pane width;
    // all remaining actions stay right-aligned in the same 30pt row.
    private func footerRow(showFollowCaret: Bool, truncateTitle: Bool) -> some View {
        HStack(spacing: 4) {
            Text(paneTitle(selectedTab))
                .fontWeight(.medium)
                .lineLimit(1)
                .fixedSize(horizontal: !truncateTitle, vertical: false)
            Spacer(minLength: truncateTitle ? 4 : 8)
            HStack(spacing: 4) {
                if selectedTab == .preview {
                    MemoWeaverThemePicker(selection: $previewAppearance, scope: "\u{BBF8}\u{B9AC}\u{BCF4}\u{AE30}",
                                          presentation: .cycleButton)
                    if showFollowCaret { followCaretButton }
                }
                ratioCycleButton
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var followCaretButton: some View {
        Button { followPreviewCaret.toggle() } label: {
            Image(systemName: "scope")
                .frame(width: 28, height: MemoWeaverPaneFooterMetrics.controlHeight)
        }
        .buttonStyle(.plain)
        .modifier(MemoWeaverFooterControl(selected: followPreviewCaret))
        .memoTooltip(followPreviewCaret ? "커서 위치 따라가기: 켜짐" : "커서 위치 따라가기: 꺼짐")
        .accessibilityLabel("커서 위치 따라가기")
        .accessibilityValue(followPreviewCaret ? "켜짐" : "꺼짐")
    }

    // One click changes the native divider. Label measures the ACTUAL widths,
    // so manual drag and window resizing never leave a misleading preset text.
    private var ratioCycleButton: some View {
        let percent = editorRatioPercent ?? 50
        return Button {
            onApplyRatio(MemoWeaverPaneRatioPreset.next(afterEditorPercent: editorRatioPercent))
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "rectangle.split.2x1")
                    .font(.system(size: 12))
                Text("\(percent):\(100 - percent)")
                    .monospacedDigit()
            }
            .frame(height: MemoWeaverPaneFooterMetrics.controlHeight)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(MemoWeaverFooterControl())
        .memoTooltip("편집창:보조창 비율 · 누를 때마다 50:50 → 60:40 → 70:30 순환")
        .accessibilityLabel("편집창과 보조창 비율 순환")
        .accessibilityValue("\(percent):\(100 - percent)")
    }
}

private struct NoteListRow: View {
    let note: WorkNote
    let typeName: String
    let bookNames: [String]
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 5) {
            HStack(spacing: 5) {
                if note.pinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2).foregroundStyle(.orange)
                }
                Text(note.visibleTitle)
                    .font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Spacer(minLength: 4)
                Text(String(note.updatedAt.prefix(10)))
                    .font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
            }
            Text(note.plainBody.replacingOccurrences(of: "\n", with: " "))
                .font(.caption).foregroundStyle(.secondary).lineLimit(compact ? 1 : 2)
            if !compact {
                HStack(spacing: 6) {
                    Label(typeName, systemImage: "tag")
                        .lineLimit(1)
                    if let first = bookNames.first {
                        Label(first, systemImage: "folder")
                            .lineLimit(1)
                        if bookNames.count > 1 {
                            Text("+\(bookNames.count - 1)")
                                .memoTooltip(bookNames.joined(separator: " · "))
                        }
                    }
                }
                .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, compact ? 2 : 5)
    }
}

// The retired rich-text NoteEditorScreen and its private history view were removed.
// All notes use MarkdownNoteEditorScreen; legacy HTML is migrated lazily and safely.

private struct ArchiveScreen: View {
    @EnvironmentObject private var model: WorkOSModel
    @State private var archiveSearch = ""
    @State private var showArchiveFullText = false

    private var filtered: [WorkArchive] {
        archiveSearch.isEmpty ? model.archives : model.archives.filter {
            $0.name.localizedCaseInsensitiveContains(archiveSearch)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("기존 원문 · 읽기 전용").font(.headline)
                    Spacer()
                }
                .padding(14)
                TextField("파일명 찾기", text: $archiveSearch)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 12).padding(.bottom, 10)
                Divider()
                List(selection: $model.selectedArchiveID) {
                    ForEach(filtered) { archive in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(archive.name).fontWeight(.semibold).lineLimit(2)
                            Text("\(archive.lineCount.formatted())줄 · \(WorkOSDate.display(archive.addedAt))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .tag(archive.id)
                    }
                }
                .listStyle(.inset)
            }
            .frame(minWidth: 210, idealWidth: 290, maxWidth: 350)
            Divider()
            if let selected = model.archives.first(where: { $0.id == model.selectedArchiveID }) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selected.name).font(.title3).bold()
                            Text("읽기 전용 사본 · \(selected.lineCount.formatted())줄")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("이 자료에 대해 질문") {
                            model.aiQuestion = "\(selected.name)에서 중요한 내용은?"
                            model.selectedPage = .assistant
                        }
                    }
                    .padding(.horizontal, 19).padding(.top, 17)
                    Divider()
                    if model.archiveFocusFromLine > 0 {
                        HStack {
                            Text("AI가 참고한 구간: \(model.archiveFocusFromLine)~\(model.archiveFocusToLine)행 (앞뒤 8행 포함)")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Toggle("전체 원문", isOn: $showArchiveFullText)
                                .toggleStyle(.checkbox)
                        }
                        .padding(.horizontal, 18)
                    }
                    ReadonlyTextView(text: model.archiveFocusFromLine > 0 && !showArchiveFullText ?
                        model.archiveExcerpt(selected.id, fromLine: model.archiveFocusFromLine, toLine: model.archiveFocusToLine) :
                        model.archiveText(selected.id))
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "archivebox").font(.system(size: 40)).foregroundStyle(.secondary)
                    Text("검색에서 연결된 원문을 열 수 있습니다").font(.title3)
                    Text("기존에 가져온 원문과 가상색인은 삭제되지 않았습니다.")
                        .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { if model.selectedArchiveID == nil { model.selectedArchiveID = model.archives.first?.id } }
        .onChange(of: model.selectedArchiveID) { _ in showArchiveFullText = false }
        .onChange(of: model.archiveFocusFromLine) { _ in showArchiveFullText = false }
    }
}

private struct AssistantScreen: View {
    @EnvironmentObject private var model: WorkOSModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("AI 기억 비서", systemImage: "brain.head.profile")
                            .font(.system(size: 24, weight: .bold))
                        Text("저장한 메모와 원문 아카이브에서 관련 근거를 찾아, Mac에 설치된 Ollama가 답변합니다.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        Label(model.aiConnected ? "Ollama 연결됨" : "연결 확인 필요",
                              systemImage: model.aiConnected ? "checkmark.circle.fill" : "circle.dotted")
                            .foregroundColor(model.aiConnected ? .green : .secondary)
                            .font(.caption)
                        Button(model.isCheckingAI ? "확인 중…" : "연결 확인") {
                            Task { await model.checkAI() }
                        }
                        .disabled(model.isCheckingAI)
                    }
                }
                GroupBox {
                    HStack(spacing: 16) {
                        Picker("사용 모델", selection: $model.aiModelName) {
                            if model.aiModels.isEmpty { Text("연결 확인을 눌러 주세요").tag(model.aiModelName) }
                            ForEach(model.aiModels) { modelEntry in Text(modelEntry.name).tag(modelEntry.name) }
                        }
                        .frame(maxWidth: 330)
                        Spacer()
                        Label("메모 \(model.activeNotes.count)개", systemImage: "doc.text")
                        Label("원문 \(model.archives.count)개", systemImage: "archivebox")
                    }
                    .padding(.vertical, 5)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("내 업무 기억에 질문하기").font(.headline)
                    TextEditor(text: $model.aiQuestion)
                        .font(.system(size: 14))
                        .frame(minHeight: 100, maxHeight: 120)
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.secondary.opacity(0.22)))
                    HStack {
                        Text("관련 자료가 없으면 모델에 질문을 보내지 않습니다.")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        if model.aiBusy {
                            ProgressView().controlSize(.small)
                            Button("중단") { model.stopAI() }
                        } else {
                            Button { model.askAI() } label: {
                                Label("기록을 근거로 답변", systemImage: "sparkles")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!model.aiConnected || model.aiQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("답변").font(.headline)
                        Spacer()
                        if !model.aiResponse.isEmpty {
                            Label("근거 확인 필요", systemImage: "checkmark.shield")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if !model.aiError.isEmpty {
                        Text(model.aiError).foregroundStyle(.red)
                            .textSelection(.enabled)
                    } else if model.aiResponse.isEmpty {
                        Text("질문을 입력하면 실제 메모에서 근거를 찾은 다음 답변합니다. 원문에 기록되지 않은 사실을 AI가 추측할 수 있으니 출처를 확인하세요.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(model.aiResponse)
                            .font(.system(size: 14))
                            .textSelection(.enabled)
                        Text(model.aiResponse.contains("[1]") ?
                            "출처 번호가 표시되어도 AI가 해당 원문을 정확히 해석했는지는 직접 확인해야 합니다." :
                            "답변에서 [1] 등의 출처 표기를 찾지 못했습니다. 원문 확인 전 업무 결정의 근거로 쓰지 마세요.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                if !model.aiSources.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("참고한 원문 \(model.aiSources.count)건").font(.headline)
                        ForEach(model.aiSources.indices, id: \.self) { index in
                            let source = model.aiSources[index]
                            Button {
                                model.openSource(source)
                            } label: {
                                HStack(alignment: .top, spacing: 14) {
                                    Text("[\(index + 1)]").bold().frame(width: 32)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(source.title).fontWeight(.semibold)
                                        Text(source.subtitle).font(.caption).foregroundStyle(.secondary)
                                        Text(source.text.replacingOccurrences(of: "\n", with: " "))
                                            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                }
                                .padding(13)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                Text("로컬 API: 127.0.0.1:11434 · MemoWeaver은 외부 AI 서비스에 요청하지 않습니다. Ollama 자체 설정과 회사 보안 정책은 별도로 확인해야 합니다.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(28)
            .frame(maxWidth: 950, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .onAppear { if !model.aiConnected { Task { await model.checkAI() } } }
    }
}

// Settings have their own first-level navigation. The main activity rail
// remains reserved for actual note-taking workflows.
private enum MemoWeaverSettingsSection: String, CaseIterable, Identifiable {
    case appearance, editor, ai, reminders, data, categories, about
    var id: String { rawValue }
    var title: String {
        switch self {
        case .appearance: return "화면"
        case .editor: return "편집기"
        case .ai: return "기억·AI"
        case .reminders: return "일정·알림"
        case .data: return "데이터·백업"
        case .categories: return "노트북·종류"
        case .about: return "앱 정보"
        }
    }
    var symbol: String {
        switch self {
        case .appearance: return "paintpalette"
        case .editor: return "textformat"
        case .ai: return "brain.head.profile"
        case .reminders: return "calendar.badge.clock"
        case .data: return "externaldrive"
        case .categories: return "folder"
        case .about: return "info.circle"
        }
    }
}

private struct SettingsScreen: View {
    @EnvironmentObject private var model: WorkOSModel
    @AppStorage("memoweaver.settings.section") private var selectedSection = "appearance"
    @AppStorage("workos.appearance") private var appearance = "system"
    @AppStorage(MarkdownPreviewMode.defaultsKey) private var markdownPreviewMode = MarkdownPreviewMode.memo.rawValue
    @AppStorage("workos.notifications.revealDetails") private var revealNotificationDetails = false
    @AppStorage("memoweaver.editor.syntaxColorsEnabled") private var syntaxColorsEnabled = true
    @AppStorage("memoweaver.ui.tooltipsEnabled") private var tooltipsEnabled = true
    @AppStorage(MemoryIdlePolicy.defaultsKey) private var backgroundMode = "automatic"
    @AppStorage("memoryhome.typography.fontSize") private var editorFontSize = EditorTypographyRules.defaultSize
    @AppStorage("memoryhome.typography.lineHeight") private var editorLineHeight = EditorTypographyRules.defaultLineHeight
    @State private var newBookName = ""
    @State private var newTypeName = ""

    var body: some View {
        ScrollViewReader { proxy in
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                Text("설정")
                    .font(.system(size: 18, weight: .semibold))
                    .padding(.horizontal, 10).padding(.bottom, 12)
                ForEach(MemoWeaverSettingsSection.allCases) { section in
                    Button {
                        selectedSection = section.rawValue
                        // Keep each section mounted with a stable identity;
                        // only the scroll position changes, with no page transition.
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            proxy.scrollTo(section.rawValue, anchor: .top)
                        }
                    } label: {
                        Label(section.title, systemImage: section.symbol)
                            .font(.system(size: 13, weight: selectedSection == section.rawValue ? .semibold : .regular))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10).frame(height: 36)
                            .background(selectedSection == section.rawValue ? Color.accentColor.opacity(0.12) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(selectedSection == section.rawValue ? "선택됨" : "선택되지 않음")
                }
                Spacer(minLength: 8)
            }
            .padding(12)
            .frame(width: 205)
            .frame(maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
            Divider()
            ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                HStack {
                    Text("설정")
                        .font(.system(size: 24, weight: .bold))
                    Spacer()
                    Text(WorkOSBuildInfo.display).font(.caption).foregroundStyle(.secondary)
                }
                ForEach(MemoWeaverSettingsSection.allCases) { section in
                    VStack(alignment: .leading, spacing: 14) {
                        Text(section.title)
                            .font(.system(size: 21, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        categoryContent(section)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(section.rawValue)
                }
            }
            .padding(28)
            .frame(maxWidth: 850, alignment: .leading)
            .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            // Restore the last visited section without rebuilding any of the
            // seven content pages. Default category starts at the top naturally.
            guard let saved = MemoWeaverSettingsSection(rawValue: selectedSection),
                  saved != .appearance else { return }
            DispatchQueue.main.async {
                proxy.scrollTo(saved.rawValue, anchor: .top)
            }
        }
        }
    }

    @ViewBuilder
    private func categoryContent(_ section: MemoWeaverSettingsSection) -> some View {
        switch section {
        case .appearance:
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("도움말 풍선") {
                    Toggle("버튼에 마우스를 올리면 기능 설명 표시", isOn: $tooltipsEnabled)
                        .toggleStyle(.switch)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("화면 모드") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("테마", selection: $appearance) {
                            Text("시스템 설정 따르기").tag("system")
                            Text("라이트").tag("light")
                            Text("다크").tag("dark")
                        }
                        .pickerStyle(.segmented)
                        Text("선택한 화면 모드는 앱을 다시 열어도 유지됩니다. 본문 편집기도 시스템 색상을 따릅니다.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .editor:
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("글쓰기 · 한글 가독성") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("본문 글자 크기")
                            Spacer()
                            Text("\(Int(EditorTypographyRules.fontSize(editorFontSize)))pt")
                                .monospacedDigit().foregroundStyle(.secondary)
                        }
                        HStack(spacing: 15) {
                            Text("가")
                                .font(.system(size: 13))
                            Slider(value: $editorFontSize, in: 13...24, step: 1)
                            Text("가")
                                .font(.system(size: 24))
                        }
                        Picker("줄 간격", selection: $editorLineHeight) {
                            Text("보통").tag(1.3)
                            Text("넉넉하게").tag(1.5)
                            Text("매우 넉넉하게").tag(1.7)
                        }
                        .pickerStyle(.segmented)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("오늘의 업무 기록")
                                .font(.system(size: EditorTypographyRules.fontSize(editorFontSize), weight: .semibold))
                            Text("기존 메모를 살펴보고 새로운 업무 내용을 기록합니다. 한글과 영문을 함께 써도 편하게 읽을 수 있도록 설정합니다.")
                                .font(.system(size: EditorTypographyRules.fontSize(editorFontSize)))
                                .lineSpacing(EditorTypographyRules.extraLeading(fontSize: editorFontSize, lineHeight: editorLineHeight))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        HStack {
                            Text("모든 메모의 편집기에 적용됩니다. 원본 텍스트·서식을 지우지 않습니다.")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button("기본값 복원") {
                                editorFontSize = EditorTypographyRules.defaultSize
                                editorLineHeight = EditorTypographyRules.defaultLineHeight
                            }
                        }
                        Text("단축키: ⌘+ / ⌘- 로 크기 조절 · ⌘0 초기화")
                            .font(.caption2).foregroundStyle(.secondary)
                        Divider()
                        Toggle("Markdown 문법 색상 표시", isOn: $syntaxColorsEnabled)
                        Text("편집기 글자가 보이지 않거나 표시가 깜박이면 이 옵션을 꺼서 일반 텍스트 색상으로 표시할 수 있습니다. 메모 원문과 저장 데이터는 변하지 않습니다.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(10)
                }
                GroupBox("Markdown 미리보기 · 메모 우선") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("미리보기 해석", selection: $markdownPreviewMode) {
                            Text("메모식 Markdown").tag(MarkdownPreviewMode.memo.rawValue)
                            Text("표준 Markdown").tag(MarkdownPreviewMode.standard.rawValue)
                        }
                        .pickerStyle(.segmented)
                        Text(markdownPreviewMode == MarkdownPreviewMode.memo.rawValue
                             ? "Enter 한 번도 줄을 바꿉니다. 일반 텍스트의 Tab 들여쓰기는 코드 블록 대신 들여쓴 문장으로 보여줍니다."
                             : "연속 문장의 줄바꿈은 공백으로 합칩니다. 문장 앞 공백 4칸은 코드 블록으로 해석합니다.")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("선택한 해석은 미리보기와 HTML·PDF 내보내기에 적용됩니다. 입력 원문·SQLite 저장·Markdown 내보내기는 바뀌지 않습니다.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                }
                GroupBox("편집기 · Markdown 원문") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: "# 제목   ·   ## 소제목   ·   ### 작은 제목   ·   > 인용   ·   - 목록   ·   1. 번호 목록")
                        Text(verbatim: "- [ ] 체크 항목   ·   **굵게**   ·   *기울임*   ·   ~~취소선~~   ·   `코드`   ·   [링크](https://...)")
                        Text("편집기는 Markdown 원문을 그대로 보관하며 문법에만 색상을 표시합니다. 미리보기에서 제목·표·수식·다이어그램으로 해석됩니다. 메모식 줄바꿈은 위 설정에서 변경할 수 있습니다.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .ai:
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("AI · 성능과 집중") {
                    VStack(alignment: .leading, spacing: 9) {
                        Picker("AI 백그라운드 처리", selection: $backgroundMode) {
                            Text("자동 최적화 (기본)").tag("automatic")
                            Text("Mac 유휴 상태에서만").tag("systemIdle")
                            Text("수동 실행").tag("manual")
                        }
                        .onChange(of: backgroundMode) { _, _ in model.backgroundModeDidChange() }
                        Text("자동 최적화: 입력 중에는 AI를 멈춥니다. 편집 중단 또는 다른 앱 사용 중 시스템 여유가 있을 때 변경된 기록을 색인하고 관계를 분석합니다. 저전력·발열 상태에서는 대기합니다.")
                            .font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 10) {
                            Button("과거 기억 일괄 분석 예약") { model.scheduleFullMemoryAnalysis() }
                                .disabled(backgroundMode == "manual")
                            Text("긴 메모의 가상 구간도 포함 · 유휴 시간에 순차 분석")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Text(model.backgroundAIStatus).font(.caption2).foregroundStyle(.secondary)
                        Text(model.memoryIndexStatus).font(.caption2).foregroundStyle(.secondary)
                        Button("AI 기억 비서 전체 화면 열기") { model.selectedPage = .assistant }
                        Text("메모 작성 중의 질문은 보조창 > AI 탭에서 바로 할 수 있습니다.")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("AI가 없어도 메모·검색·일정·백업은 그대로 작동합니다.")
                            .font(.caption2).foregroundStyle(.secondary)
                        Text("추천의 유사도 점수는 정답 확률이 아닙니다. AI 답변은 반드시 원문을 확인해 주세요.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .reminders:
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("로컬 일정 알림") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(model.notificationStatus).font(.callout)
                        HStack {
                            Button("Mac 알림 권한 요청") { model.requestReminderPermission() }
                            Button("시스템 알림 설정 열기") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        }
                        Toggle("잠금 화면 알림에 일정 제목과 마감일 표시", isOn: $revealNotificationDetails)
                            .onChange(of: revealNotificationDetails) { _ in model.rescheduleReminders() }
                        Text("기본값은 제목 숨김입니다. 알림은 Mac에만 예약되며 외부 서버로 전송되지 않습니다. 시스템 알림 허용과 집중 모드에 따라 실제 표시가 달라질 수 있습니다.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .data:
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("로컬 데이터와 백업") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(model.storagePath).font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled).foregroundStyle(.secondary)
                        Text("편집 시 SQLite 자동 저장. 스냅샷은 6시간 단위로 생성 가능하며 앱 실행·재활성화·사용 중 주기적으로 확인합니다. 최근 최대 28개(약 512MB 제한, 최신 2개 우선)를 보관하며 다른 디스크에 대한 별도 백업을 대체하지는 않습니다.")
                            .font(.callout).foregroundStyle(.secondary)
                        Text("최근 SQLite 스냅샷: " + model.backupStatus)
                            .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Button("전체 JSON 백업") { model.exportBackupDialog() }
                            Button("JSON 백업 시점으로 전체 복원…") { model.restoreBackupDialog() }
                            Button("SQLite 스냅샷 지금 만들기") { model.backupNow() }
                            Button("저장 위치 Finder에서 보기") { model.revealStorage() }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                }
                    // Legacy archives and virtual-memory pointers remain in
                    // SQLite and in semantic search. Retired import/index UI
                    // is deliberately absent from public settings.
                    Text("이전에 불러온 원문과 생성된 기억 색인은 계속 보관되며 검색할 수 있습니다.")
                        .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .categories:
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("내 노트북") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            TextField("새 노트북 이름", text: $newBookName)
                                .textFieldStyle(.roundedBorder)
                            Button("추가") {
                                model.createCategory(kind: "book", name: newBookName)
                                newBookName = ""
                            }
                            .disabled(newBookName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        Text(model.books.map(\.name).joined(separator: " · ").isEmpty ? "아직 만든 노트북이 없습니다." : model.books.map(\.name).joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                }
                GroupBox("메모 종류 직접 만들기") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            TextField("새 종류 이름", text: $newTypeName)
                                .textFieldStyle(.roundedBorder)
                            Button("추가") {
                                model.createCategory(kind: "type", name: newTypeName)
                                newTypeName = ""
                            }
                            .disabled(newTypeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        Text("메모 종류는 언제든 변경할 수 있으며 본문은 유지됩니다.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .about:
            VStack(alignment: .leading, spacing: 16) {
                    GroupBox("MemoWeaver") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(WorkOSBuildInfo.display)
                                .font(.system(size: 15, weight: .semibold))
                            Text("로컬 SQLite 기반 메모·일정·선택형 Ollama AI")
                                .foregroundStyle(.secondary)
                            LabeledContent("데이터 위치", value: model.storagePath)
                            LabeledContent("AI 상태", value: model.aiConnected ? "연결됨" : "연결 전 / 확인 필요")
                            LabeledContent("백업", value: model.backupStatus)
                            Text("기존 앱의 번들 식별자와 데이터 경로를 유지합니다. 메모나 첨부파일을 서버로 전송하지 않습니다. 외부 AI 연결과 회사 보안 정책은 별도로 확인하세요.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                    }
                Text("MemoWeaver는 기록을 우선합니다. 메모와 첨부파일은 로컬에 보관되고, AI 기능은 선택적으로 사용할 수 있습니다.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
