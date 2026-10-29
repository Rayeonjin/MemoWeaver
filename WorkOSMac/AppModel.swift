import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum WorkspacePage: Hashable {
    case all, today, planner, trash, archives, search, assistant, memory, settings
    // A sidebar route, not another storage table: kind notes still live in notes.
    case kind(String)

    var kindID: String? {
        if case .kind(let id) = self { return id }
        return nil
    }

    var isActiveNotesPage: Bool {
        self == .all || kindID != nil
    }
}

@MainActor
final class WorkOSModel: ObservableObject {
    @Published var notes: [WorkNote] = []
    @Published var types: [WorkCategory] = []
    @Published var books: [WorkCategory] = []
    @Published var archives: [WorkArchive] = []
    @Published var chunks: [WorkChunk] = []
    @Published var virtualMemories: [VirtualMemory] = []
    @Published var staleVirtualSources: Set<String> = []
    // Revision-aware local cache: avoid rehashing every unchanged large source
    // on each category/filter/save refresh. Cache is never persisted or trusted
    // as an AI source without validation of its revision.
    var virtualSourceSignatureCache: [String: (revision: String, signature: String)] = [:]
    @Published var isAnalyzingVirtual = false
    @Published var virtualAnalysisStatus = "긴 메모에서 가상 메모를 만들 수 있습니다. 원문은 그대로 유지됩니다."
    @Published var virtualAnalysisProgress = 0.0
    @Published var virtualAnalysisTarget = ""
    @Published var noteFocusLine = 0
    @Published var noteFocusNoteID = ""
    @Published var noteFocusRequestID = UUID()
    @Published var scheduleItems: [WorkScheduleItem] = []
    @Published var notificationStatus = "Mac 알림 권한 확인 중"
    @Published var selectedScheduleItemID: String?
    @Published var selectedPage: WorkspacePage = .all
    @Published var notesScope: NotesListScope = .all
    @Published var selectedBookFilterID = ""
    @Published var selectedTypeFilterID = ""
    @Published var restoredArchivedCount = 0
    @Published var selectedNoteID: String?
    // Prevent a disappearing editor from re-saving stale content after a
    // destructive whole-database restore. Also forces view identity refresh.
    @Published var dataGeneration = UUID()
    // UI-only caret offsets, intentionally not Published or persisted to SQLite:
    // selection changes must not invalidate the entire editor while typing.
    var editorCaretOffsets: [String: Int] = [:]
    @Published var selectedArchiveID: String?
    @Published var archiveFocusFromLine = 0
    @Published var archiveFocusToLine = 0
    @Published var alertText: String?
    @Published var statusMessage = "로컬 저장소 준비 중"
    @Published var checkpointSignal = UUID()
    @Published var aiQuestion = ""
    @Published var aiResponse = ""
    @Published var aiError = ""
    @Published var aiSources: [MemorySource] = []
    @Published var aiModels: [OllamaTag] = []
    @Published var aiModelName = "qwen3.5:4b"
    @Published var aiConnected = false
    @Published var aiBusy = false
    @Published var isCheckingAI = false
    @Published var storagePath = ""
    @Published var backupStatus = "아직 확인하지 않음"
    @Published var embeddingAvailable = false
    @Published var isIndexingMemory = false
    @Published var memoryIndexStatus = "아직 의미 색인을 생성하지 않았습니다."
    @Published var memoryIndexProgress = 0.0
    @Published var memoryThreshold = UserDefaults.standard.object(forKey: "workos.memory.threshold") as? Double ?? 0.64
    @Published var memoryVectors: [MemoryVector] = []
    @Published var confirmedMemoryLinks: [MemoryLink] = []
    @Published var inferredMemoryRelations: [MemoryInferredRelation] = []
    @Published var inferredMemoryFacts: [MemoryFact] = []
    @Published var memoryRelationReviews: [MemoryRelationReview] = []
    @Published var isInferringMemory = false
    @Published var inferenceStatus = "원문 근거를 확인하는 AI 관계 분석을 실행할 수 있습니다."
    @Published var inferenceProgress = 0.0
    @Published var memoryGraph = MemoryGraphData()
    var memoryGraphQuery = ""
    @Published var backgroundAIStatus = "자동 최적화 · 메모 입력 우선"
    var lastEditorActivityAt = Date()
    var backgroundLastAppActivityAt = Date()
    // Presentation-only throttle; never written to the database.
    var lastEditorAIPauseAt = Date.distantPast
    var backgroundCorpusPending = false
    var backgroundQueueRestored = false
    var backgroundNoteQueue: Set<String> = []
    var backgroundRelationQueue: Set<String> = []
    var backgroundAITask: Task<Void, Never>?
    var backgroundAIRevision = 0
    var isAutomaticMemoryIndexing = false
    var isAutomaticRelationAnalysis = false
    var memoryCacheLoaded = false
    // Presentation caches: never persisted, never used as evidence for AI.
    // Invalidated whenever note/virtual content, links, or embeddings change.
    var sideRelationCache: [String: [MemoryInferredRelation]] = [:]
    var sideFactsCache: [String: [MemoryFact]] = [:]
    var sideNeighborsCache: [String: [MemoryNeighbor]] = [:]
    var sideRangeCache: [String: [SideMemoryRange]] = [:]
    var activeRelationCache: [MemoryInferredRelation]?
    func invalidateMemoryDisplayCaches() {
        sideRelationCache.removeAll()
        sideFactsCache.removeAll()
        sideNeighborsCache.removeAll()
        sideRangeCache.removeAll()
        activeRelationCache = nil
    }

    let referenceReader = MemoryReferenceWindowCoordinator()
    var database: LocalDatabase?
    let ollama = OllamaService()
    var memoryIndexTask: Task<Void, Never>?
    var liveMemoryTask: Task<Void, Never>?
    var virtualAnalysisTask: Task<Void, Never>?
    var relationInferenceTask: Task<Void, Never>?
    private var answerTask: Task<Void, Never>?
    private var answerGeneration = UUID()
    private var backupPreflightBusy = false

    init() {
        do {
            let db = try LocalDatabase()
            database = db
            storagePath = db.databaseURL.path
            var backupIssue: String?
            var recoveryIssue: String?
            do {
                // This method creates a pre-change SQLite snapshot BEFORE touching a legacy flag.
                restoredArchivedCount = try db.restoreLegacyArchivedNotesSafely()
                let snapshot = try db.snapshotBackupIfNeeded()
                backupStatus = snapshot.lastPathComponent
            } catch { recoveryIssue = error.localizedDescription }
            // Keep all old notes visible even if a backup/migration cannot complete.
            if backupStatus == "아직 확인하지 않음" {
                do { backupStatus = try db.snapshotBackupIfNeeded().lastPathComponent }
                catch { backupIssue = error.localizedDescription }
            }
            try refresh(keepSelection: false)
            if let lastID = UserDefaults.standard.string(forKey: "memoweaver.notes.lastOpenedID"),
               notes.contains(where: { $0.id == lastID && $0.deletedAt.isEmpty }) {
                selectedNoteID = lastID
            }
            try bootstrapMemory()
            checkReminderPermission()
            if let backupIssue {
                statusMessage = "SQLite 저장 가능 · 자동 백업 점검 필요"
                alertText = "메모 저장소는 열렸지만 자동 백업에 실패했습니다. JSON 수동 백업을 권장합니다.\n\n" + backupIssue
            } else if let recoveryIssue {
                statusMessage = "메모는 표시됨 · 보관 상태 복구 확인 필요"
                alertText = "이전 보관 메모를 복귀하는 과정에서 오류가 발생했습니다. 내용은 그대로 표시됩니다.\n\n" + recoveryIssue
            } else if restoredArchivedCount > 0 {
                statusMessage = "기존 보관 메모 \(restoredArchivedCount)개 복귀 · 자동 저장"
            } else {
                statusMessage = "SQLite에 자동 저장"
            }
        } catch {
            alertText = error.localizedDescription
            statusMessage = "저장소 오류 — 데이터가 저장되지 않습니다"
        }
    }

    func refresh(keepSelection: Bool = true) throws {
        guard let database else { return }
        let prior = keepSelection ? selectedNoteID : nil
        notes = try database.notes()
        types = try database.categories(kind: "type")
        books = try database.categories(kind: "book")
        archives = try database.archives()
        chunks = try database.archiveChunks()
        // Cached virtual pointers are revision-validated; stale ones are kept
        // in SQLite solely to allow explicit re-analysis without data loss.
        reloadVirtualMemories()
        scheduleItems = try database.scheduledItems()
        if let prior, notes.contains(where: { $0.id == prior }) { selectedNoteID = prior }
        else { selectedNoteID = notes.first(where: { $0.deletedAt.isEmpty })?.id }
    }

    var activeNotes: [WorkNote] { notes.filter { $0.deletedAt.isEmpty } }
    var currentNote: WorkNote? { notes.first(where: { $0.id == selectedNoteID }) }
    var filteredNotes: [WorkNote] {
        // Compute local date boundaries once, not once per note (important for large lists).
        let today = WorkOSDate.day()
        let recentStart = WorkOSDate.day(Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date())
        return notes.filter { note in
            if selectedPage == .trash { return !note.deletedAt.isEmpty }
            guard selectedPage.isActiveNotesPage else { return false }
            // A category shortcut is a fixed type filter. The existing filter menu
            // remains available for the all-notes route only.
            let typeFilter = selectedPage.kindID ?? selectedTypeFilterID
            return NotesListFilter.matches(note, scope: notesScope,
                bookID: selectedBookFilterID, typeID: typeFilter,
                today: today, recentStart: recentStart)
        }.sorted {
            if selectedPage != .trash && $0.pinned != $1.pinned { return $0.pinned }
            return $0.updatedAt > $1.updatedAt
        }
    }

    func resetNoteFilters() {
        notesScope = .all
        selectedBookFilterID = ""
        selectedTypeFilterID = ""
    }

    func selectVisibleNoteAfterFiltering() {
        // A scoped list is not the editor's document identity. Never replace
        // the active note simply because it no longer matches a filter.
        if let selected = currentNote, selected.deletedAt.isEmpty { return }
        selectedNoteID = filteredNotes.first?.id
    }

    func openNote(_ id: String, focusLine: Int = 0) {
        guard notes.contains(where: { $0.id == id && $0.deletedAt.isEmpty }) else { return }
        resetNoteFilters()
        noteFocusLine = focusLine
        noteFocusNoteID = focusLine > 0 ? id : ""
        noteFocusRequestID = UUID()
        selectedNoteID = id
        selectedPage = .all
    }

    func typeName(_ id: String) -> String { types.first(where: { $0.id == id })?.name ?? "일반 메모" }
    func bookName(_ id: String) -> String { books.first(where: { $0.id == id })?.name ?? "노트북 없음" }
    func notebookNames(for note: WorkNote) -> [String] {
        note.notebookIDs.compactMap { id in books.first(where: { $0.id == id })?.name }
    }

    // MARK: - Backup: never blocks note editing on a missing AI connection.

    func backupIfNeeded() {
        guard let database else { return }
        do {
            let snapshot = try database.snapshotBackupIfNeeded()
            backupStatus = snapshot.lastPathComponent
        } catch {
            backupStatus = "자동 백업 실패: " + error.localizedDescription
        }
    }

    func backupNow() {
        guard let database else { return }
        do {
            let snapshot = try database.snapshotBackupIfNeeded(force: true)
            backupStatus = snapshot.lastPathComponent
            statusMessage = "SQLite 스냅샷 저장됨"
        } catch {
            backupStatus = "백업 실패: " + error.localizedDescription
            show(error)
        }
    }

    // MARK: - Local planner; the Google Calendar account is never accessed.

    func saveSchedule(_ item: WorkScheduleItem) -> Bool {
        guard let database else { return false }
        do {
            try database.saveScheduleItem(item)
            scheduleItems = try database.scheduledItems()
            rescheduleReminders()
            statusMessage = "일정 저장됨 · \(WorkOSDate.display(WorkOSDate.now()))"
            return true
        } catch { show(error); statusMessage = "일정 저장 실패"; return false }
    }

    func deleteSchedule(_ item: WorkScheduleItem) {
        guard let database else { return }
        do {
            try database.deleteScheduleItem(item.id)
            scheduleItems = try database.scheduledItems()
            rescheduleReminders()
            statusMessage = "일정 삭제됨"
        } catch { show(error) }
    }

    func toggleScheduleComplete(_ item: WorkScheduleItem) {
        var changed = item
        changed.markDone(!item.isCompleted)
        _ = saveSchedule(changed)
    }

    func openSchedule(_ id: String) {
        guard let item = scheduleItems.first(where: { $0.id == id }) else { return }
        if let note = notes.first(where: { $0.id == item.noteID && $0.deletedAt.isEmpty }) {
            openNote(note.id)
        } else {
            selectedScheduleItemID = id
            selectedPage = .planner
        }
    }

    func checkReminderPermission() {
        WorkOSReminderService.shared.queryPermission { [weak self] label, granted in
            guard let self else { return }
            self.notificationStatus = label
            if granted { self.rescheduleReminders() }
        }
    }

    func requestReminderPermission() {
        WorkOSReminderService.shared.requestPermission { [weak self] status in
            guard let self else { return }
            self.notificationStatus = status
            self.rescheduleReminders()
        }
    }

    func rescheduleReminders() {
        WorkOSReminderService.shared.synchronize(items: scheduleItems,
            revealDetails: UserDefaults.standard.bool(forKey: "workos.notifications.revealDetails"))
    }

    // One action in every screen: creates an ordinary note with an immediately editable body.
    func newNoteFromShortcut() {
        // Creating inside filtered notes inherits their category and notebook.
        let selectedType = selectedPage.kindID ??
            (selectedPage.isActiveNotesPage && !selectedTypeFilterID.isEmpty
                ? selectedTypeFilterID : "type-note")
        createNote(typeID: selectedType)
    }

    // A single creation path: preserve current filters and leave the new note
    // visible in its original list. Explicit creation from another workspace
    // opens the notes page without inheriting unrelated old filters.
    func createNote(typeID: String = "type-note", markdown: Bool = true) {
        guard let database else { return }
        do {
            let fromNotes = selectedPage.isActiveNotesPage
            let previousNote = currentNote
            let bookID = fromNotes ? selectedBookFilterID : ""
            let shouldPin = fromNotes && notesScope == .pinned
            let note = try database.createNote(typeID: typeID, markdown: markdown,
                                               bookID: bookID, pinned: shouldPin)
            try refresh()
            if !fromNotes {
                resetNoteFilters()
                selectedPage = .all
            } else if let previous = previousNote,
                      (UserDefaults.standard.string(forKey: "memoweaver.rightPane.visibility") ?? "automatic") == "automatic" {
                // A brand-new note inherits the previous note's *effective*
                // pane visibility, rather than re-triggering automatic preview.
                // An explicit open/closed preference and the native split
                // width are already shared across note selection unchanged.
                let rawTab = UserDefaults.standard.string(forKey: "memoweaver.rightPane.activeTab") ?? "preview"
                let tab = NoteSidePaneTab(rawValue: rawTab) ?? .preview
                let wasOpen = NoteSidePaneRules.isVisibleForLayout(
                    preference: "automatic", compactNavigation: true, tab: tab,
                    bodyHTML: previous.bodyHTML, blocks: previous.workosBlocks,
                    isMarkdown: previous.isMarkdown)
                UserDefaults.standard.set(wasOpen ? "open" : "closed",
                                          forKey: "memoweaver.rightPane.visibility")
            }
            selectedNoteID = note.id
            statusMessage = "새 메모 생성됨 · 자동 저장"
        } catch { show(error) }
    }

    // Images are written atomically before their Markdown source is inserted.
    // Never convert a failed paste into a broken link in the note.
    func storePastedPNG(_ data: Data, for noteID: String) -> String? {
        guard let database, notes.contains(where: { $0.id == noteID && $0.deletedAt.isEmpty }) else {
            alertText = "이미지 붙여넣기 실패: 현재 메모 또는 저장소를 확인할 수 없습니다."
            return nil
        }
        do {
            let path = try MemoWeaverAttachments.storePNG(data, in: database.directory)
            statusMessage = "이미지 첨부 저장됨"
            return "![이미지](\(path))"
        } catch {
            alertText = "이미지 붙여넣기 실패: " + error.localizedDescription
            return nil
        }
    }

    func saveNote(_ originalID: String, title: String, bodyHTML: String?, typeID: String,
                  bookID: String, noteDate: String, status: String, sourceURL: String,
                  pinned: Bool, archived: Bool, checkpoint: Bool,
                  convertLegacyBodyToMarkdown: Bool = false,
                  notebookIDs: [String]? = nil) -> Bool {
        guard let database, let old = notes.first(where: { $0.id == originalID }) else { return false }
        do {
            statusMessage = "저장 중…"
            let saved = try database.saveNote(old, title: title,
                bodyHTML: bodyHTML ?? old.bodyHTML, typeID: typeID, bookID: bookID,
                noteDate: noteDate, status: status, sourceURL: sourceURL,
                pinned: pinned, archived: archived, checkpoint: checkpoint,
                convertLegacyBodyToMarkdown: convertLegacyBodyToMarkdown,
                notebookIDs: notebookIDs)
            if let index = notes.firstIndex(where: { $0.id == saved.id }) { notes[index] = saved }
            statusMessage = "저장됨 · \(WorkOSDate.display(WorkOSDate.now()))"
            if saved.updatedAt != old.updatedAt {
                invalidateVirtualSourceAfterEdit(kind: "note", id: saved.id)
                invalidateMemoryDisplayCaches()
                queueLiveMemoryIndex(noteID: saved.id)
            }
            return true
        } catch {
            statusMessage = "저장 실패"
            show(error)
            return false
        }
    }

    func saveBlocks(noteID: String, blocks: [WorkBlock], checkpoint: Bool) -> Bool {
        guard let database, let old = notes.first(where: { $0.id == noteID }) else { return false }
        do {
            let updated = try database.saveBlocks(old, blocks: blocks, checkpoint: checkpoint)
            if let index = notes.firstIndex(where: { $0.id == updated.id }) { notes[index] = updated }
            if old.plainBody != updated.plainBody {
                invalidateVirtualSourceAfterEdit(kind: "note", id: updated.id)
                invalidateMemoryDisplayCaches()
                queueLiveMemoryIndex(noteID: updated.id)
            }
            return true
        } catch { show(error); statusMessage = "확장 블록 저장 실패"; return false }
    }

    func checkpoint() { checkpointSignal = UUID() }

    func markDeleted(_ note: WorkNote, deleted: Bool) {
        guard let database else { return }
        do {
            _ = try database.updateDeleted(note, delete: deleted)
            try refresh()
            queueLiveMemoryIndex(noteID: note.id)
            regenerateMemoryGraphIfVisible()
            if deleted {
                selectedNoteID = filteredNotes.first?.id
                statusMessage = "휴지통으로 이동됨"
            } else if selectedPage == .trash {
                // Restoring the currently selected deleted note must never
                // display a blank editor on the Trash page.
                openNote(note.id)
                statusMessage = "복원된 메모를 열었습니다"
            }
        } catch { show(error) }
    }

    func addProgress(noteID: String, text: String) {
        guard let database, let note = notes.first(where: { $0.id == noteID }) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            _ = try database.addProgress(to: note, body: trimmed)
            try refresh()
            queueLiveMemoryIndex(noteID: noteID)
        } catch { show(error) }
    }

    func createCategory(kind: String, name: String) {
        guard let database else { return }
        do {
            try database.createCategory(name: name, kind: kind)
            try refresh()
        } catch { show(error) }
    }

    func importArchivesDialog() {
        let picker = NSOpenPanel()
        picker.message = "메모 텍스트를 선택하세요. 확장자가 없어도 됩니다. 원본 파일은 변경하지 않습니다."
        picker.canChooseDirectories = false
        picker.canChooseFiles = true
        picker.allowsMultipleSelection = true
        picker.allowedContentTypes = []
        picker.allowsOtherFileTypes = true
        if picker.runModal() == .OK { importArchives(picker.urls) }
    }

    func importArchives(_ urls: [URL]) {
        guard let database else { return }
        var imported = 0
        var errors: [String] = []
        for url in urls {
            do {
                let raw = try Data(contentsOf: url, options: .mappedIfSafe)
                let decoded = try ArchiveDecoder.read(raw)
                if try database.addArchive(name: url.lastPathComponent, content: decoded.text) { imported += 1 }
            } catch { errors.append("\(url.lastPathComponent): \(error.localizedDescription)") }
        }
        do { try refresh() } catch { show(error) }
        if imported > 0 { requestBackgroundCorpusIndex() }
        statusMessage = "텍스트 자료 \(imported)개 가져옴"
        if !errors.isEmpty {
            alertText = "\(imported)개 가져옴. 실패한 파일:\n" + errors.prefix(8).joined(separator: "\n")
        }
    }

    func openArchive(_ id: String) {
        selectedArchiveID = id
        archiveFocusFromLine = 0
        archiveFocusToLine = 0
        selectedPage = .archives
    }

    func openArchiveExcerpt(_ id: String, fromLine: Int, toLine: Int) {
        openArchive(id)
        archiveFocusFromLine = fromLine
        archiveFocusToLine = toLine
    }

    func archiveExcerpt(_ id: String, fromLine: Int, toLine: Int) -> String {
        // Match virtual line pointers exactly. CharacterSet.newlines would
        // count both CR and LF separately in Windows CRLF archives.
        let lines = VirtualMemoryCore.lines(archiveText(id))
        guard fromLine > 0, !lines.isEmpty else { return archiveText(id) }
        let start = max(1, fromLine - 8)
        let end = min(lines.count, max(fromLine, toLine) + 8)
        guard start <= end else { return "" }
        return (start...end).map { index in
            "\(index) | \(lines[index - 1])"
        }.joined(separator: "\n")
    }
    func archiveText(_ id: String) -> String {
        do { return try database?.archiveText(id: id) ?? "" }
        catch { show(error); return "" }
    }

    func deleteArchive(id: String) {
        guard let database else { return }
        do {
            try database.deleteArchive(id: id)
            reloadVirtualMemories()
            if selectedArchiveID == id { selectedArchiveID = nil }
            try refresh()
            try bootstrapMemory()
        } catch { show(error) }
    }

    func importLegacyBackupDialog() {
        let picker = NSOpenPanel()
        picker.allowedContentTypes = [.json]
        picker.allowsMultipleSelection = false
        picker.message = "JSON 기록 추가: 현재 기록을 유지하고 없는 항목만 가져옵니다. 이전 시점으로 되돌리는 기능은 '전체 복원'을 사용하세요."
        guard picker.runModal() == .OK, let file = picker.url else { return }
        do {
            guard let database else { return }
            let data = try LocalDatabase.readBackupData(from: file)
            let added = try database.importBrowserBackup(data)
            try refresh()
            try bootstrapMemory()
            requestBackgroundCorpusIndex()
            rescheduleReminders()
            statusMessage = "이전 기록 가져오기 완료"
            alertText = "이전 기록을 가져왔습니다.\n새 노트 \(added.notes)개, 과거 파일 \(added.archives)개 추가.\n같은 ID의 기존 노트는 덮어쓰지 않았습니다."
        } catch { show(error) }
    }

    func restoreBackupDialog() {
        guard let database, !backupPreflightBusy else { return }
        let picker = NSOpenPanel()
        picker.allowedContentTypes = [.json]
        picker.allowsMultipleSelection = false
        picker.message = "전체 복원: 현재 기록을 선택한 JSON 백업 시점으로 교체합니다. 먼저 자동 SQLite 스냅샷을 만듭니다."
        guard picker.runModal() == .OK, let file = picker.url else { return }
        backupPreflightBusy = true
        Task { @MainActor in
            defer { backupPreflightBusy = false }
            do {
                let (data, incomingCount, archiveCount, incomingScheduleCount) = try await Task.detached(priority: .userInitiated) {
                    let data = try LocalDatabase.readBackupData(from: file)
                    guard let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          MemoWeaverScheduleBackupPreflight.acceptsApp(raw),
                          MemoWeaverScheduleBackupPreflight.preservesSchedules(raw),
                          raw["schema"] as? Int == 1,
                          let incoming = raw["notes"] as? [[String: Any]],
                          let archives = raw["sources"] as? [[String: Any]] else {
                        throw LocalDatabase.Failure.badBackup
                    }
                    try LocalDatabase.validateReplacementCollections(raw)
                    return (data, incoming.count, archives.count, (raw["scheduleItems"] as? [[String: Any]])?.count ?? 0)
                }.value
                let warning = NSAlert()
                warning.alertStyle = .critical
                warning.messageText = "모든 기록을 백업 시점으로 복원하시겠습니까?"
                warning.informativeText = "현재 메모 \(notes.count)개와 자료 \(self.archives.count)개를 교체합니다. 선택한 JSON에는 메모 \(incomingCount)개, TXT \(archiveCount)개가 있습니다. 시작 전 SQLite 복구 스냅샷을 만들고 실패 시 변경을 롤백합니다. 현재 편집 내용이 저장되어 있는지 확인하세요."
                warning.informativeText += "\n\n일정도 함께 교체됩니다. 현재 \(scheduleItems.count)건 → 백업 \(incomingScheduleCount)건. 구형 백업에 일정 정보가 없으면 일정은 0건으로 복원됩니다."
                warning.addButton(withTitle: "취소")
                warning.addButton(withTitle: "전체 복원 실행")
                guard warning.runModal() == .alertSecondButtonReturn else { return }
                let restored = try database.replaceAllWithVerifiedBrowserBackup(data)
                // Never write old on-screen drafts into the newly restored database.
                dataGeneration = UUID()
                virtualSourceSignatureCache.removeAll()
                UserDefaults.standard.set(UUID().uuidString, forKey: "memoweaver.storage.recoveryEpoch")
                selectedNoteID = nil
                try refresh(keepSelection: false)
                try bootstrapMemory()
                resetNoteFilters()
                selectedPage = .all
                requestBackgroundCorpusIndex()
                rescheduleReminders()
                statusMessage = "전체 복원 완료"
                alertText = "전체 복원을 마쳤습니다. 메모 \(restored.notes)개, TXT 자료 \(restored.archives)개. 복원 직전 SQLite 스냅샷은 설정의 백업 폴더에서 확인할 수 있습니다."
        } catch { show(error) }
        }
    }

    func exportBackupDialog() {
        guard let database else { return }
        let picker = NSSavePanel()
        picker.allowedContentTypes = [.json]
        picker.nameFieldStringValue = "MemoWeaver_\(WorkOSDate.day())_backup.json"
        guard picker.runModal() == .OK, let destination = picker.url else { return }
        do {
            try database.exportBrowserCompatibleJSON().write(to: destination, options: .atomic)
            statusMessage = "JSON 백업 생성 완료"
        } catch { show(error) }
    }

    func revealStorage() {
        if let database { NSWorkspace.shared.activateFileViewerSelecting([database.databaseURL]) }
    }

    func show(_ error: Error) { alertText = error.localizedDescription }

    func checkAI() async {
        guard !isCheckingAI else { return }
        isCheckingAI = true
        defer { isCheckingAI = false }
        do {
            let result = try await ollama.models()
            // An embedding-only model must not appear in the chat model selector.
            aiModels = result.filter(\.supportsChat)
            aiConnected = !aiModels.isEmpty
            embeddingAvailable = result.contains(where: { $0.name == "bge-m3" || $0.name == "bge-m3:latest" })
            aiError = ""
            if !embeddingAvailable { memoryIndexStatus = "bge-m3를 Ollama에서 확인하지 못했습니다." }
            if !aiModels.contains(where: { $0.name == aiModelName }) {
                aiModelName = aiModels.first(where: { $0.name == "qwen3.5:4b" })?.name ?? aiModels.first?.name ?? ""
            }
        } catch {
            aiConnected = false
            embeddingAvailable = false
            aiModels = []
            aiError = "모델 목록 연결 실패: \(error.localizedDescription)"
        }
    }

    func askAI() {
        if aiBusy || !aiConnected { return }
        let question = aiQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        aiResponse = ""
        aiError = ""
        aiBusy = true
        let generation = UUID()
        answerGeneration = generation
        answerTask = Task {
            defer {
                if answerGeneration == generation { aiBusy = false; answerTask = nil }
            }
            do {
                let sources = await hybridMemorySources(for: question)
                guard !Task.isCancelled, answerGeneration == generation else { return }
                aiSources = sources
                guard !sources.isEmpty else {
                    aiError = "관련 기록을 찾지 못했습니다. 새 자료를 색인하거나 질문의 핵심 단어를 바꿔 보세요."
                    return
                }
                let answer = try await ollama.answer(model: aiModelName, question: question, sources: sources)
                if !Task.isCancelled, answerGeneration == generation { aiResponse = answer }
            } catch is CancellationError {
                if answerGeneration == generation { aiError = "응답을 중단했습니다." }
            } catch {
                if answerGeneration == generation { aiError = error.localizedDescription }
            }
        }
    }

    func stopAI() {
        answerGeneration = UUID()
        answerTask?.cancel(); answerTask = nil; aiBusy = false
        aiError = "응답을 중단했습니다."
    }

    func openSource(_ source: MemorySource) {
        let entity = source.id.hasPrefix("virtual:") ? source.id :
            (source.kind == "archive" ? "archive:" + source.sourceID : "note:" + source.sourceID)
        openReferenceEntity(entity, fromLine: source.fromLine, toLine: source.toLine)
    }

    func related(to note: WorkNote) -> [WorkNote] {
        let query = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return notes.filter { $0.id != note.id && $0.deletedAt.isEmpty }
            .map { ($0, WorkOSSearch.matchScore(question: query, candidate: $0.plainBody, title: $0.title)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(5).map { $0.0 }
    }
}
