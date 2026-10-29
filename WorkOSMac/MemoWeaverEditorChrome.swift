import SwiftUI
import AppKit

// The notebook/type pickers are lightly filled, not bordered. They remain
// fixed-width one-level menus with a neutral chevron and full hit target.
private struct MemoWeaverControlSurface: ViewModifier {
    @State private var hovered = false
    func body(content: Content) -> some View {
        content
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(hovered ? 0.085 : 0.035)))
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .onHover { hovered = $0 }
    }
}

// Quiet, discoverable inline attributes. No system-blue menu arrow and
// no large toolbar controls for metadata that is edited only occasionally.
private struct MemoWeaverMetadataSurface: ViewModifier {
    @State private var hovered = false
    func body(content: Content) -> some View {
        content
            .font(.system(size: 12))
            .foregroundStyle(hovered ? Color.primary : Color.secondary)
            .padding(.horizontal, 7)
            .frame(height: 24)
            .background(Color.primary.opacity(hovered ? 0.065 : 0.025),
                        in: RoundedRectangle(cornerRadius: 5))
            .contentShape(RoundedRectangle(cornerRadius: 5))
            .onHover { hovered = $0 }
    }
}

// The note header is a separate SwiftUI type to avoid compiler expression
// timeouts when the editor, preview, sheet and toolbar share a ViewBuilder.
struct MemoWeaverEditorHeader: View {
    // The list toggle is the LEFT edge of the editor title row, the auxiliary
    // toggle is the RIGHT edge. The global toolbar must not duplicate them.
    private enum Metrics {
        static let bookWidth: CGFloat = 142
        static let typeWidth: CGFloat = 132
        static let pinWidth: CGFloat = 30
        static let moreWidth: CGFloat = 30
        static let compactBookWidth: CGFloat = 94
        static let compactTypeWidth: CGFloat = 88
    }
    @EnvironmentObject private var model: WorkOSModel
    let listPaneVisible: Bool
    let auxiliaryPaneVisible: Bool
    let focusMode: Bool
    @State private var showingNewBook = false
    @State private var showingNotebookPicker = false
    @State private var showingNewType = false
    @State private var showingDatePicker = false
    @State private var showingSourceEditor = false
    @State private var showingProgressEditor = false
    @Binding var title: String
    @Binding var typeID: String
    @Binding var bookID: String
    @Binding var notebookIDs: [String]
    @Binding var pinned: Bool
    @Binding var noteDay: Date
    @Binding var noteStatus: String
    @Binding var sourceURL: String
    @Binding var progressText: String
    let onAddProgress: () -> Void
    let onTrash: () -> Void
    let onRestore: () -> Void
    let isTrashed: Bool
    let fallbackTitle: String
    let onAdditionalInfo: () -> Void
    let onCheckpoint: () -> Void
    let onHistory: () -> Void
    let onExport: (WorkOSNoteExport.Format) -> Void

    // The native unified titlebar is the actual title/action row.
    // CONTENT rows are: 1 notebook/type, 2 attributes, 3 insert palette
    // (the final row lives in MarkdownNoteScreen). Same 3-row rhythm as
    // list search / scopes / notebook filters, without hiding attributes.
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) { bookMenu; typeMenu }
                    .fixedSize(horizontal: true, vertical: false)
                HStack(spacing: 6) { bookMenuCompact; typeMenuCompact }
                    .fixedSize(horizontal: true, vertical: false)
                compactClassificationMenu
            }
            .frame(height: 30, alignment: .leading)
            ViewThatFits(in: .horizontal) {
                metadataActions
                HStack(spacing: 5) {
                    dateButton
                    statusButton
                    sourceButton
                    compactPropertiesButton
                }
                .fixedSize(horizontal: true, vertical: false)
                compactPropertiesButton
            }
            .frame(height: 30, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Attach creation sheets to the header itself, not to a specific
        // ViewThatFits candidate. Ultra-narrow fallback menus must also work.
        .sheet(isPresented: $showingNewBook) {
            MemoWeaverCategoryCreationSheet(kind: "book") { id in
                selectNotebook(id)
            }
                .environmentObject(model)
        }
        .sheet(isPresented: $showingNewType) {
            MemoWeaverCategoryCreationSheet(kind: "type") { typeID = $0 }
                .environmentObject(model)
        }
    }

    private var listToggle: some View {
        Button {
            NotificationCenter.default.post(name: .memoWeaverToggleNoteList, object: nil)
        } label: {
            MemoWeaverPaneToggleGlyph(side: .left, isOpen: listPaneVisible)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(MemoWeaverHeaderIconSurface(selected: listPaneVisible, height: 30))
        .layoutPriority(2)
        .memoTooltip(listPaneVisible ? "메모 목록 닫기 (⌘⌥B)" : "메모 목록 열기 (⌘⌥B)")
        .accessibilityLabel(listPaneVisible ? "메모 목록 닫기" : "메모 목록 열기")
        .accessibilityValue(listPaneVisible ? "열림" : "닫힘")
    }

    private var auxiliaryToggle: some View {
        Button {
            NotificationCenter.default.post(name: .memoWeaverToggleRightPane, object: nil)
        } label: {
            MemoWeaverPaneToggleGlyph(side: .right, isOpen: auxiliaryPaneVisible)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(MemoWeaverHeaderIconSurface(selected: auxiliaryPaneVisible, height: 30))
        .layoutPriority(2)
        .memoTooltip(auxiliaryPaneVisible ? "보조창 닫기 (⌘⌥R)" : "보조창 열기 (⌘⌥R)")
        .accessibilityLabel(auxiliaryPaneVisible ? "보조창 닫기" : "보조창 열기")
        .accessibilityValue(auxiliaryPaneVisible ? "열림" : "닫힘")
    }

    private var focusToggle: some View {
        Button {
            NotificationCenter.default.post(name: .memoWeaverToggleFocusMode, object: nil)
        } label: {
            Image(systemName: focusMode ? "arrow.down.right.and.arrow.up.left" :
                  "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 13, weight: .medium))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(MemoWeaverHeaderIconSurface(selected: focusMode, height: 30))
        .memoTooltip(focusMode ? "집중 모드 종료 (⌘⌥F)" : "집중 모드 (⌘⌥F)")
        .accessibilityLabel(focusMode ? "집중 모드 종료" : "집중 모드")
        .accessibilityValue(focusMode ? "켜짐" : "꺼짐")
    }

    private var newNoteButton: some View {
        Button {
            NotificationCenter.default.post(name: .memoWeaverCreateNewNote, object: nil)
        } label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 13, weight: .medium))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(MemoWeaverHeaderIconSurface(height: 30))
        .memoTooltip("새 메모 만들기 (⌘N)")
        .accessibilityLabel("새 메모 만들기")
    }

    // Under a narrow editor, one directly accessible properties sheet is
    // preferable to forcing a fourth/fifth row into the writing area.
    private var compactPropertiesButton: some View {
        Button(action: onAdditionalInfo) {
            Label("속성", systemImage: "slider.horizontal.3")
                .font(.system(size: 11))
                .padding(.horizontal, 7)
                .frame(height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(MemoWeaverHeaderIconSurface(height: 28))
        .fixedSize(horizontal: true, vertical: false)
        .memoTooltip("기록일 · 상태 · 참고 URL · 진행 기록 · 연결 일정")
        .accessibilityLabel("메모 속성 편집")
    }

    // At the extreme narrow end, classification is still accessible; unlike
    // a clipped row, this fallback preserves every existing action.
    private var compactClassificationMenu: some View {
        Menu {
            Menu("노트북") { notebookChoices }
            Menu("종류") { typeChoices }
            Divider()
            Button("메모 속성…", action: onAdditionalInfo)
        } label: {
            Label("분류 · 속성", systemImage: "tag")
                .font(.system(size: 11))
                .padding(.horizontal, 8)
                .frame(height: 28)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .modifier(MemoWeaverHeaderIconSurface(height: 28))
        .memoTooltip("좁은 편집창의 노트북 · 종류 · 메모 속성")
    }

    private var metadataActions: some View {
        HStack(spacing: 5) {
            dateButton
            statusButton
            sourceButton
            progressButton
            scheduleButton
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    // The date, status, link, and progress controls are real editing actions,
    // directly bound to the existing autosave/recovery path in the note screen.
    private var dateButton: some View {
        Button { showingDatePicker = true } label: {
            Label(WorkOSDate.day(noteDay), systemImage: "calendar")
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .modifier(MemoWeaverMetadataSurface())
        .accessibilityLabel("기록일 " + WorkOSDate.day(noteDay) + ", 변경")
        .popover(isPresented: $showingDatePicker, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                Text("기록일 변경").font(.headline)
                DatePicker("기록일", selection: $noteDay, displayedComponents: .date)
                    .datePickerStyle(.field)
                Button("닫기") { showingDatePicker = false }
            }
            .padding(15)
            .frame(width: 265)
        }
    }

    private var statusButton: some View {
        Menu {
            ForEach(["진행 중", "대기", "완료", "보류"], id: \.self) { value in
                Button {
                    noteStatus = value
                } label: {
                    if noteStatus == value { Label(value, systemImage: "checkmark") }
                    else { Text(value) }
                }
            }
        } label: {
            Label(noteStatus, systemImage: "circle.dotted")
                .lineLimit(1)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .modifier(MemoWeaverMetadataSurface())
        .accessibilityLabel("진행 상태 " + noteStatus + ", 변경")
    }

    private var sourceButton: some View {
        Button { showingSourceEditor = true } label: {
            Label("URL", systemImage: "link")
        }
        .buttonStyle(.plain)
        .modifier(MemoWeaverMetadataSurface())
        .memoTooltip(sourceURL.isEmpty ? "참고 URL 추가" : "참고 URL 수정: " + sourceURL)
        .accessibilityLabel("참고 URL 수정")
        .popover(isPresented: $showingSourceEditor, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                Text("참고 URL").font(.headline)
                TextField("https://…", text: $sourceURL)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    if let address = URL(string: sourceURL),
                       address.scheme == "https" || address.scheme == "http" {
                        Button("브라우저에서 열기") { _ = NSWorkspace.shared.open(address) }
                    }
                    Spacer(minLength: 8)
                    Button("닫기") { showingSourceEditor = false }
                }
            }
            .padding(15)
            .frame(width: 350)
        }
    }

    private var progressButton: some View {
        Button { showingProgressEditor = true } label: {
            Label("진행 기록", systemImage: "text.badge.plus")
        }
        .buttonStyle(.plain)
        .modifier(MemoWeaverMetadataSurface())
        .memoTooltip("이 메모에 진행 기록 추가")
        .accessibilityLabel("진행 기록 추가")
        .popover(isPresented: $showingProgressEditor, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                Text("진행 기록 추가").font(.headline)
                TextField("진행한 작업이나 결정 사항", text: $progressText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addProgressAndClose)
                HStack {
                    Spacer(minLength: 8)
                    Button("취소") { showingProgressEditor = false }
                    Button("추가", action: addProgressAndClose)
                        .disabled(progressText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(15)
            .frame(width: 350)
        }
    }

    private var scheduleButton: some View {
        Button(action: onAdditionalInfo) {
            Label("연결 일정", systemImage: "calendar.badge.clock")
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.plain)
        .modifier(MemoWeaverMetadataSurface())
        .memoTooltip("이 메모의 연결된 일정·상세 정보")
        .accessibilityLabel("메모 일정 및 상세 정보 열기")
    }

    private func addProgressAndClose() {
        guard !progressText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        onAddProgress()
        // A failed save retains the input and shows the existing alert.
        if progressText.isEmpty { showingProgressEditor = false }
    }

    private var titleInput: some View {
        TextField(fallbackTitle, text: $title)
            .textFieldStyle(.plain)
            .font(.system(size: 17, weight: .semibold))
            .frame(minWidth: 36, maxWidth: 520, alignment: .leading)
            .accessibilityLabel("현재 메모 제목 수정")
    }

    // A flat menu has one selection level. A Menu wrapping a Picker creates
    // a second submenu on macOS, unnecessarily adding an interaction.
    private func selectNotebook(_ id: String) {
        notebookIDs = NotebookMembershipCore.toggled(id, in: notebookIDs)
        bookID = notebookIDs.first ?? ""
    }

    private var notebookChoices: some View {
        Group {
            ForEach(model.books) { item in
                Button {
                    selectNotebook(item.id)
                } label: {
                    if notebookIDs.contains(item.id) {
                        Label(item.name, systemImage: "checkmark")
                    } else {
                        Text(item.name)
                    }
                }
            }
            Divider()
            Button("새 노트북 만들기…", systemImage: "plus") { showingNewBook = true }
        }
    }

    private var notebookSelectionPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("노트북에 포함").font(.headline)
                Spacer()
                Button("완료") { showingNotebookPicker = false }
                    .keyboardShortcut(.defaultAction)
            }
            Text("메모 원본은 하나이며 선택한 모든 노트북에서 표시됩니다.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(model.books) { item in
                        Toggle(item.name, isOn: Binding(
                            get: { notebookIDs.contains(item.id) },
                            set: { selected in
                                if selected != notebookIDs.contains(item.id) {
                                    selectNotebook(item.id)
                                }
                            }
                        ))
                        .toggleStyle(.checkbox)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 230)
            Divider()
            Button("새 노트북 만들기…", systemImage: "plus") {
                showingNotebookPicker = false
                showingNewBook = true
            }
        }
        .padding(14)
        .frame(width: 275)
    }

    private var notebookDisplayName: String {
        guard let first = notebookIDs.first else { return "노트북" }
        let base = model.bookName(first)
        return notebookIDs.count > 1 ? "\(base) +\(notebookIDs.count - 1)" : base
    }

    private var notebookTooltip: String {
        let names = notebookIDs.map { model.bookName($0) }
        return names.isEmpty ? "노트북 없음 · 클릭해 여러 노트북 선택" :
            "포함된 노트북: " + names.joined(separator: ", ") + " · 클릭해 변경"
    }

    private var typeChoices: some View {
        Group {
            ForEach(model.types) { item in
                Button {
                    typeID = item.id
                } label: {
                    if typeID == item.id { Label(item.name, systemImage: "checkmark") }
                    else { Text(item.name) }
                }
            }
            Divider()
            Button("새 종류 만들기…", systemImage: "plus") { showingNewType = true }
        }
    }

    private var bookMenu: some View { notebookMenu(width: Metrics.bookWidth) }
    private var bookMenuCompact: some View { notebookMenu(width: Metrics.compactBookWidth) }

    // All sizes use the same menu content and category-creation sheet.
    private func notebookMenu(width: CGFloat) -> some View {
        Button { showingNotebookPicker.toggle() } label: {
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                Text(notebookDisplayName)
                    .lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 2)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .padding(.horizontal, 9)
            .frame(width: width, alignment: .leading)
            .modifier(MemoWeaverControlSurface())
        }
        .buttonStyle(.plain)
        .frame(width: width)
        .popover(isPresented: $showingNotebookPicker, arrowEdge: .bottom) {
            notebookSelectionPopover
        }
        .memoTooltip(notebookTooltip, when: notebookIDs.count > 1 || notebookDisplayName.count > (width < 150 ? 11 : 17))
        .accessibilityLabel(notebookTooltip)
    }

    private var typeMenu: some View { typeMenu(width: Metrics.typeWidth) }
    private var typeMenuCompact: some View { typeMenu(width: Metrics.compactTypeWidth) }

    private func typeMenu(width: CGFloat) -> some View {
        Menu { typeChoices } label: {
            HStack(spacing: 6) {
                Image(systemName: "tag").foregroundStyle(.secondary)
                Text(model.typeName(typeID))
                    .lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 2)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .padding(.horizontal, 9)
            .frame(width: width, alignment: .leading)
            .modifier(MemoWeaverControlSurface())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: width)
        .accessibilityLabel("메모 종류: " + model.typeName(typeID))
    }

    private var pinButton: some View {
        Button { pinned.toggle() } label: {
            Image(systemName: pinned ? "pin.fill" : "pin")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(pinned ? Color.orange : Color.secondary)
                .frame(width: Metrics.pinWidth, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: Metrics.pinWidth)
        .modifier(MemoWeaverHeaderIconSurface(selected: pinned))
        .memoTooltip(pinned ? "메모 고정 해제" : "이 메모 고정")
        .accessibilityLabel(pinned ? "메모 고정 해제" : "메모 고정")
        .accessibilityValue(pinned ? "고정됨" : "고정 안 됨")
    }

    private var moreMenu: some View {
        Menu {
            Button("연결된 일정 · 메모 상세 정보…", action: onAdditionalInfo)
            if isTrashed {
                Button("휴지통에서 복원", systemImage: "arrow.uturn.backward", action: onRestore)
            } else {
                Button("휴지통으로 이동…", systemImage: "trash", role: .destructive, action: onTrash)
            }
            Divider()
            Button("변경 이력 체크포인트 (⌘S)", action: onCheckpoint)
            Button("변경 이력 보기", action: onHistory)
            Divider()
            Button("Markdown 내보내기") { onExport(.markdown) }
            Button("HTML 내보내기") { onExport(.html) }
            Button("PDF 내보내기") { onExport(.pdf) }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .medium))
                .frame(width: Metrics.moreWidth, height: 30)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: Metrics.moreWidth)
        .modifier(MemoWeaverHeaderIconSurface())
        .memoTooltip("메모 더보기")
        .accessibilityLabel("메모 작업")
    }
}

// Less frequent attributes remain editable, but they never consume editor
// height or hide the insertion toolbar. The sheet does not rewrite the body.
struct MemoWeaverAdditionalNoteInfo: View {
    @Environment(\.dismiss) private var dismiss
    let note: WorkNote
    @Binding var noteDay: Date
    @Binding var noteStatus: String
    @Binding var sourceURL: String
    @Binding var progressText: String
    let onAddProgress: () -> Void
    let onDelete: () -> Void
    let onRestore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("메모 정보").font(.title2.bold())
            Text("본문과 관계없이 기록일·상태·참고 URL을 관리합니다.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            DatePicker("기록일", selection: $noteDay, displayedComponents: .date)
                .datePickerStyle(.field)
            Picker("상태", selection: $noteStatus) {
                ForEach(["진행 중", "대기", "완료", "보류"], id: \.self) {
                    Text($0).tag($0)
                }
            }
            TextField("참고 URL (선택)", text: $sourceURL)
                .textFieldStyle(.roundedBorder)
            Divider()
            Text("진행 기록 추가").font(.headline)
            HStack(spacing: 8) {
                TextField("진행 기록", text: $progressText)
                    .textFieldStyle(.roundedBorder).onSubmit(onAddProgress)
                Button("추가", action: onAddProgress)
                    .disabled(progressText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            WorkOSNoteScheduleStrip(note: note)
            Divider()
            HStack {
                if note.deletedAt.isEmpty {
                    Button("휴지통으로 이동", role: .destructive) {
                        dismiss()
                        onDelete()
                    }
                } else {
                    Button("복원") {
                        dismiss()
                        onRestore()
                    }
                }
                Spacer()
                Button("닫기") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(minWidth: 460, idealWidth: 520)
    }
}

// Keep the eight independent insertion tools in their established order.
// ViewThatFits probes intrinsically sized rows from widest to narrowest:
// 8 direct; 6 direct + overflow (2 items); 5 direct + overflow (3);
// and so on. An overflow containing only a single orphaned footnote is
// deliberately never generated. No fixed editor-width thresholds are used.
struct MemoWeaverInsertToolbar: View {
    @State private var tableGridPresented = false
    // ViewThatFits builds several alternative rows. A popover must be tied to
    // the *actual* table icon (or overflow menu), not to the full-width bar.
    @State private var tableGridOriginRow: Int? = nil
    let onInsert: (MarkdownTemplates.Kind) -> Void
    let onInsertChart: (MermaidChartTemplates.Kind) -> Void
    let onInsertDiagram: (MermaidDiagramTemplates.Kind) -> Void
    let onInsertTable: (Int, Int) -> Void
    let onInsertExtra: (MemoWeaverSourceTemplate) -> Void
    let onInsertCode: (MemoWeaverCodeTemplates) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            insertionRow(visibleCount: 9)  // Nine tools + compact advanced syntax menu.
            insertionRow(visibleCount: 8)
            insertionRow(visibleCount: 7)
            insertionRow(visibleCount: 6)  // Six tools + overflow.
            insertionRow(visibleCount: 5)  // Five tools + ellipsis for three.
            insertionRow(visibleCount: 4)
            insertionRow(visibleCount: 3)
            insertionRow(visibleCount: 2)
            insertionRow(visibleCount: 1)
            insertionRow(visibleCount: 0)  // On the narrowest editor, ellipsis alone.
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 30)
        .buttonStyle(.plain)
        .controlSize(.small)
        .font(.system(size: 12, weight: .medium))
    }

    private func tablePickerBinding(for row: Int) -> Binding<Bool> {
        Binding(get: { tableGridPresented && tableGridOriginRow == row }, set: { open in
            if !open {
                tableGridPresented = false
                tableGridOriginRow = nil
            }
        })
    }

    private var tablePicker: some View {
        MemoWeaverTableSizeGrid { cols, rows in
            tableGridPresented = false
            tableGridOriginRow = nil
            onInsertTable(cols, rows)
        }
        .padding(13)
    }

    // In the visible toolbar and in overflow, charts and infrequent diagrams
    // remain their own nested menus. The primary flowchart is one click.
    private var diagramChoices: some View {
        ForEach(MermaidDiagramTemplates.Kind.allCases, id: \.self) { kind in
            Button(kind.title) { onInsertDiagram(kind) }
        }
    }

    private var diagramMenu: some View {
        Menu { diagramChoices } label: {
            Image(systemName: "square.stack.3d.up")
                .frame(width: 26, height: 26)
                .accessibilityLabel("도식")
        }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .modifier(MemoWeaverHeaderIconSurface(height: 26))
            .fixedSize(horizontal: true, vertical: false)
            .memoTooltip("Mermaid 도식 템플릿")
    }

    private var chartMenu: some View {
        Menu { chartChoices } label: {
            Image(systemName: "chart.bar.xaxis")
                .frame(width: 26, height: 26)
                .accessibilityLabel("차트")
        }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .modifier(MemoWeaverHeaderIconSurface(height: 26))
            .fixedSize(horizontal: true, vertical: false)
            .memoTooltip("Mermaid XY 막대·선·혼합 그래프 및 원형 차트")
    }

    private var chartChoices: some View {
        ForEach(MermaidChartTemplates.Kind.allCases, id: \.self) { chart in
            Button(chart.title) { onInsertChart(chart) }
        }
    }

    // The advanced syntax menu deliberately excludes bold, italic, headings,
    // numbered/bulleted lists and dividers: experienced users type those.
    // Extra tools do not add a second row or widen the main editor.
    private var advancedSyntaxMenu: some View {
        Menu {
            Menu("코드 언어") {
                ForEach(MemoWeaverCodeTemplates.allCases, id: \.self) { language in
                    Button(language.title) { onInsertCode(language) }
                }
            }
            Divider()
            ForEach(MemoWeaverMarkdownExtras.Group.allCases, id: \.self) { group in
                Menu(group.rawValue) {
                    ForEach(MemoWeaverMarkdownExtras.items(group)) { item in
                        Button(item.title) { onInsertExtra(item) }
                    }
                }
            }
        } label: {
            Image(systemName: "text.badge.plus")
                .frame(width: 26, height: 26)
                .accessibilityLabel("추가 Markdown 도구")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .modifier(MemoWeaverHeaderIconSurface(height: 26))
        .fixedSize(horizontal: true, vertical: false)
        .memoTooltip("추가 문법·코드 언어")
    }

    private func insertionRow(visibleCount: Int) -> some View {
        let kinds: [MarkdownTemplates.Kind] = [
            .table, .code, .equation, .mermaid, .markmap, .chart, .diagram, .callout, .footnote
        ]
        return HStack(spacing: 4) {
            ForEach(Array(kinds.prefix(visibleCount)), id: \.self) { kind in
                if kind == .mermaid || kind == .callout {
                    Rectangle().fill(Color.secondary.opacity(0.20))
                        .frame(width: 1, height: 15)
                        .padding(.horizontal, 3)
                        .accessibilityHidden(true)
                }
                if kind == .chart {
                    chartMenu
                } else if kind == .diagram {
                    diagramMenu
                } else if kind == .mermaid {
                    Button { onInsert(.mermaid) } label: {
                        Image(systemName: "arrow.triangle.branch")
                            .frame(width: 26, height: 26)
                    }
                    .modifier(MemoWeaverHeaderIconSurface(height: 26))
                    .accessibilityLabel("순서도")
                        .fixedSize(horizontal: true, vertical: false)
                        .memoTooltip("Mermaid 흐름도 바로 삽입")
                } else if kind == .table {
                    Button {
                        tableGridOriginRow = visibleCount
                        tableGridPresented = true
                    } label: {
                        Image(systemName: "tablecells")
                            .frame(width: 26, height: 26)
                    }
                    .modifier(MemoWeaverHeaderIconSurface(height: 26))
                    .accessibilityLabel("표")
                        .fixedSize(horizontal: true, vertical: false)
                        .memoTooltip("가로·세로 격자에서 Markdown 표 크기 선택")
                        .popover(isPresented: tablePickerBinding(for: visibleCount),
                                 attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                            tablePicker
                        }
                } else {
                    Button { onInsert(kind) } label: {
                        Image(systemName: kind.symbol)
                            .frame(width: 26, height: 26)
                    }
                        .modifier(MemoWeaverHeaderIconSurface(height: 26))
                        .accessibilityLabel(kind.title)
                        .fixedSize(horizontal: true, vertical: false)
                        .memoTooltip(kind.title + " 삽입")
                }
            }
            if visibleCount < kinds.count {
                Menu {
                    ForEach(Array(kinds.dropFirst(visibleCount)), id: \.self) { kind in
                        if kind == .chart {
                            Menu("차트") { chartChoices }
                        } else if kind == .diagram {
                            Menu("도식") { diagramChoices }
                        } else if kind == .mermaid {
                            Button("순서도") { onInsert(.mermaid) }
                        } else if kind == .table {
                            Button("표 · 행/열 선택…") {
                                // Let the native menu dismiss before showing the
                                // picker on its visible overflow trigger.
                                DispatchQueue.main.async {
                                    tableGridOriginRow = visibleCount
                                    tableGridPresented = true
                                }
                            }
                        } else {
                            Button(kind.title) { onInsert(kind) }
                        }
                    }
                } label: {
                    Label("나머지 삽입 도구", systemImage: "ellipsis")
                        .labelStyle(.iconOnly)
                        .frame(width: 26, height: 26)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .modifier(MemoWeaverHeaderIconSurface(height: 26))
                .memoTooltip("공간이 부족해 숨겨진 삽입 도구 \(kinds.count - visibleCount)개")
                .accessibilityLabel("나머지 삽입 도구 \(kinds.count - visibleCount)개")
                .popover(isPresented: tablePickerBinding(for: visibleCount),
                         attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                    tablePicker
                }
            }
            Rectangle().fill(Color.secondary.opacity(0.20))
                .frame(width: 1, height: 15)
                .padding(.horizontal, 2)
                .accessibilityHidden(true)
            advancedSyntaxMenu
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

// Scratch/Notion-style quick table insertion. The grid only produces Markdown
// text via the existing insertion channel; it does not replace NSTextView.
private struct MemoWeaverTableSizeGrid: View {
    @State private var selectedColumns = 3
    @State private var selectedRows = 3
    let onChoose: (Int, Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("표 크기 선택").font(.headline)
            Text("\(selectedColumns)열 × \(max(2, selectedRows))행 · 첫 행은 머리글")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(1...8, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(1...8, id: \.self) { column in
                        Button {
                            onChoose(column, max(2, row))
                        } label: {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(column <= selectedColumns && row <= selectedRows
                                    ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.11))
                                .overlay(RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(Color.secondary.opacity(0.28), lineWidth: 0.7))
                                .frame(width: 23, height: 21)
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            if hovering { selectedColumns = column; selectedRows = max(row, 2) }
                        }
                        .memoTooltip("\(column)열 × \(max(2, row))행")
                        .accessibilityLabel("\(column)열 \(max(2, row))행 표 삽입")
                    }
                }
            }
        }
        .frame(width: 215)
    }
}

// Editor footer theme cycles with one click. The preview footer has its own
// independent selection and uses the same cycle interaction.
struct MemoWeaverEditorStatusBar: View {
    @AppStorage("memoryhome.typography.fontSize") private var fontSize = EditorTypographyRules.defaultSize
    @AppStorage("workos.appearance") private var appearance = "system"
    let caretLine: Int
    let caretColumn: Int
    let totalLines: Int
    let characterCount: Int
    let saveLabel: String

    private var saveIndicator: some View {
        let failed = saveLabel == "저장 실패"
        let waiting = saveLabel.contains("대기") || saveLabel.contains("저장 중")
        let symbol = failed ? "exclamationmark.circle.fill" :
                     (waiting ? "clock.arrow.circlepath" : "checkmark.circle")
        let detail = failed ? "메모 저장 실패 · 작성 중인 내용의 복구 파일을 확인하세요." :
                     (waiting ? "변경사항이 있어 자동 저장을 기다리는 중입니다." :
                                "메모 저장 상태: " + saveLabel)
        return Image(systemName: symbol)
            .foregroundStyle(failed ? Color.red : Color.secondary)
            .fixedSize(horizontal: true, vertical: false)
            .memoTooltip(detail)
            .accessibilityLabel(detail)
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 7) {
                saveIndicator
                editorControls(compact: false)
                Spacer(minLength: 8)
                Text("\(caretLine)행 \(caretColumn)열 · \(totalLines.formatted())줄 · \(characterCount.formatted())자")
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            HStack(spacing: 5) {
                editorControls(compact: false)
                Spacer(minLength: 2)
                saveIndicator
                Text("\(caretLine):\(caretColumn) · \(characterCount.formatted())자")
                    .lineLimit(1).fixedSize(horizontal: true, vertical: false)
            }
            HStack(spacing: 5) {
                editorControls(compact: true)
                Spacer(minLength: 1)
                saveIndicator
            }
            editorControls(compact: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(MemoWeaverPaneFooterSurface())
    }

    private func editorControls(compact: Bool) -> some View {
        let buttonWidth: CGFloat = compact ? 27 : 33
        let valueWidth: CGFloat = compact ? 35 : 42
        return HStack(spacing: compact ? 2 : 4) {
            // The - / pt / + controls already explain their purpose. Avoid
            // consuming footer width with a redundant decorative glyph.
            if fontSize > EditorTypographyRules.minimumSize {
                statusButton("minus", label: "글자 작게", width: buttonWidth) {
                    fontSize = EditorTypographyRules.zoom(fontSize, by: -1)
                }
            } else {
                Color.clear.frame(width: buttonWidth,
                                  height: MemoWeaverPaneFooterMetrics.controlHeight)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
            Button { fontSize = EditorTypographyRules.defaultSize } label: {
                Text("\(Int(EditorTypographyRules.fontSize(fontSize)))pt")
                    .monospacedDigit()
                    .frame(width: valueWidth, height: MemoWeaverPaneFooterMetrics.controlHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .modifier(MemoWeaverFooterControl())
            .memoTooltip("기본 글자 크기 복원")
            .accessibilityLabel("편집기 글자 크기 기본값 복원")
            if fontSize < EditorTypographyRules.maximumSize {
                statusButton("plus", label: "글자 크게", width: buttonWidth) {
                    fontSize = EditorTypographyRules.zoom(fontSize, by: 1)
                }
            } else {
                Color.clear.frame(width: buttonWidth,
                                  height: MemoWeaverPaneFooterMetrics.controlHeight)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
            Rectangle().fill(Color.secondary.opacity(0.20))
                .frame(width: 1, height: 16).padding(.horizontal, compact ? 2 : 4)
            MemoWeaverThemePicker(selection: $appearance, scope: "앱",
                                  presentation: .cycleButton)
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .contain)
    }

    private func statusButton(_ icon: String, label: String,
                              width: CGFloat,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .frame(width: width, height: MemoWeaverPaneFooterMetrics.controlHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(MemoWeaverFooterControl())
        .memoTooltip(label)
        .accessibilityLabel(label)
    }
}
