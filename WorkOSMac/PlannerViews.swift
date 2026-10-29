import AppKit
import SwiftUI

private enum PlannerScope: String, CaseIterable {
    case day = "선택한 날짜"
    case upcoming = "다가오는 일정"
    case overdue = "기한 경과"
    case completed = "완료"
}

struct WorkOSPlannerScreen: View {
    @EnvironmentObject private var model: WorkOSModel
    @State private var viewingMonth = Date()
    @State private var daySelected = WorkOSDate.day()
    @State private var scope: PlannerScope = .day
    @State private var editorItem: WorkScheduleItem?
    @State private var now = Date()

    private var sortedItems: [WorkScheduleItem] {
        let base: [WorkScheduleItem]
        switch scope {
        case .day: base = model.scheduleItems.filter { $0.dueDay == daySelected }
        case .upcoming: base = model.scheduleItems.filter {
            !$0.isCompleted && !$0.isOverdue(now: now) &&
                ScheduleDates.dayDifference(from: now, to: $0.dueDay) >= 0
        }
        case .overdue: base = model.scheduleItems.filter { $0.isOverdue(now: now) }
        case .completed: base = model.scheduleItems.filter(\.isCompleted)
        }
        return base.sorted {
            if scope == .completed { return $0.completedAt > $1.completedAt }
            if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
            if $0.dueDay != $1.dueDay { return $0.dueDay < $1.dueDay }
            return $0.dueTime < $1.dueTime
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Label("일정 · D-Day", systemImage: "calendar.badge.clock").font(.title2.bold())
                Spacer()
                Text("MemoWeaver 내부 일정 · 외부 캘린더 연결 없음")
                    .font(.caption).foregroundStyle(.secondary)
                Button { editorItem = .make(dueDay: daySelected) } label: {
                    Label("새 일정", systemImage: "plus")
                }.buttonStyle(.borderedProminent)
            }
            summary
            HSplitView {
                VStack(alignment: .leading, spacing: 14) {
                    monthCalendar
                    Divider()
                    HStack(spacing: 8) {
                        Image(systemName: "bell")
                        Text(model.notificationStatus)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                    .font(.caption).foregroundStyle(.secondary)
                    Button("Mac 알림 권한 요청") { model.requestReminderPermission() }
                        .controlSize(.small)
                    Text("알림을 허용하지 않아도 앱 안의 D-day와 일정 목록은 작동합니다. 알림은 Mac 시스템 설정과 집중 모드의 영향을 받습니다.")
                        .font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(15)
                .frame(minWidth: 295, idealWidth: 360, maxWidth: 400)
                VStack(alignment: .leading, spacing: 12) {
                    Picker("보기", selection: $scope) {
                        ForEach(PlannerScope.allCases, id: \.self) { item in Text(item.rawValue).tag(item) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    HStack {
                        Text(scope == .day ? "\(daySelected) 마감 일정" : scope.rawValue)
                            .font(.headline)
                        Spacer()
                        Text("\(sortedItems.count)건").font(.caption).foregroundStyle(.secondary)
                    }
                    Divider()
                    if sortedItems.isEmpty {
                        ContentUnavailableView("표시할 일정이 없습니다", systemImage: "calendar",
                            description: Text("메모에서 후속 일정을 추가하거나 위의 '새 일정' 버튼을 사용하세요."))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 9) {
                                ForEach(sortedItems) { item in
                                    WorkOSScheduleRow(item: item, now: now,
                                        onEdit: { editorItem = item })
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding(16)
                .frame(minWidth: 435, maxWidth: .infinity)
            }
        }
        .padding(20)
        .sheet(item: $editorItem) { item in
            WorkOSScheduleEditorSheet(initial: item) { changed in
                model.saveSchedule(changed)
            }
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { value in now = value }
        .onAppear {
            model.checkReminderPermission()
            scrollToSpotlight()
        }
        .onChange(of: model.selectedScheduleItemID) { _ in scrollToSpotlight() }
    }

    private func scrollToSpotlight() {
        guard let id = model.selectedScheduleItemID,
              let item = model.scheduleItems.first(where: { $0.id == id }),
              let day = ScheduleDates.parseDay(item.dueDay) else { return }
        viewingMonth = day
        daySelected = item.dueDay
        scope = .day
    }

    private var summary: some View {
        let today = model.scheduleItems.filter { $0.isDueToday(now: now) }.count
        let overdue = model.scheduleItems.filter { $0.isOverdue(now: now) }.count
        let coming = model.scheduleItems.filter {
            !$0.isCompleted && !($0.isOverdue(now: now)) &&
                ScheduleDates.dayDifference(from: now, to: $0.dueDay) >= 0
        }.count
        return HStack(spacing: 10) {
            summaryPill("오늘 마감", count: today, icon: "sun.max", tint: .blue) {
                daySelected = WorkOSDate.day(now)
                viewingMonth = now
                scope = .day
            }
            summaryPill("기한 경과", count: overdue, icon: "exclamationmark.circle", tint: .orange) { scope = .overdue }
            summaryPill("다가오는 일정", count: coming, icon: "calendar", tint: .teal) { scope = .upcoming }
            Spacer(minLength: 0)
        }
    }

    private func summaryPill(_ name: String, count: Int, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon).foregroundStyle(tint)
                Text(name).font(.caption)
                Text("\(count)").fontWeight(.bold)
            }
            .padding(.horizontal, 13).padding(.vertical, 9)
            .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var monthCalendar: some View {
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year,.month], from: viewingMonth)) ?? viewingMonth
        let weekday = calendar.component(.weekday, from: monthStart)
        let leading = (weekday + 5) % 7 // Monday-first grid.
        let gridStart = calendar.date(byAdding: .day, value: -leading, to: monthStart) ?? monthStart
        let counts = Dictionary(grouping: model.scheduleItems.filter { !$0.isCompleted }, by: \.dueDay).mapValues(\.count)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월"
        return VStack(spacing: 11) {
            HStack {
                Button { moveMonth(-1) } label: { Image(systemName: "chevron.left") }.buttonStyle(.borderless)
                Spacer()
                Text(formatter.string(from: viewingMonth)).font(.headline)
                Spacer()
                Button("오늘") {
                    viewingMonth = now
                    daySelected = WorkOSDate.day(now)
                    scope = .day
                }.font(.caption).buttonStyle(.borderless)
                Button { moveMonth(1) } label: { Image(systemName: "chevron.right") }.buttonStyle(.borderless)
            }
            HStack(spacing: 4) {
                ForEach(["월","화","수","목","금","토","일"], id: \.self) { name in
                    Text(name).font(.caption2).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 4) {
                ForEach(0..<42, id: \.self) { index in
                    let date = calendar.date(byAdding: .day, value: index, to: gridStart) ?? gridStart
                    let key = WorkOSDate.day(date)
                    let activeMonth = calendar.isDate(date, equalTo: viewingMonth, toGranularity: .month)
                    let count = counts[key] ?? 0
                    Button {
                        daySelected = key
                        scope = .day
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(calendar.component(.day, from: date))")
                                .font(.caption.weight(key == WorkOSDate.day(now) ? .bold : .regular))
                                .foregroundStyle(key == daySelected ? Color.white :
                                    (activeMonth ? Color.primary : Color.secondary.opacity(0.45)))
                            if count > 0 {
                                Text("\(count)건")
                                    .font(.system(size: 9))
                                    .foregroundStyle(key == daySelected ? Color.white : Color.accentColor)
                            } else { Text(" ").font(.system(size: 9)) }
                        }
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(key == daySelected ? Color.accentColor.opacity(0.9) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 7))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(key == daySelected ? Color.white : Color.primary)
                }
            }
        }
    }
    private func moveMonth(_ delta: Int) {
        viewingMonth = Calendar.current.date(byAdding: .month, value: delta, to: viewingMonth) ?? viewingMonth
    }
}

private struct WorkOSScheduleRow: View {
    @EnvironmentObject private var model: WorkOSModel
    let item: WorkScheduleItem
    let now: Date
    let onEdit: () -> Void
    @State private var showDelete = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button { model.toggleScheduleComplete(item) } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isCompleted ? Color.green : Color.secondary)
            }
            .buttonStyle(.borderless)
            .memoTooltip(item.isCompleted ? "완료 취소" : "완료로 표시")
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Text(item.title)
                        .fontWeight(.semibold)
                        .strikethrough(item.isCompleted)
                        .foregroundStyle(item.isCompleted ? Color.secondary : Color.primary)
                    Text(item.dDay)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(item.isOverdue(now: now) ? Color.orange.opacity(0.18) : Color.accentColor.opacity(0.12),
                                    in: Capsule())
                    Spacer(minLength: 0)
                }
                Text(item.dueDay + (item.dueTime.isEmpty ? " · 종일" : " · " + item.dueTime))
                    .font(.caption).foregroundStyle(item.isOverdue(now: now) ? Color.orange : Color.secondary)
                if !item.details.isEmpty {
                    Text(item.details).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                if !item.noteID.isEmpty {
                    Button {
                        model.openSchedule(item.id)
                    } label: {
                        Label(model.notes.first(where: { $0.id == item.noteID })?.visibleTitle ?? "연결된 메모 열기",
                              systemImage: "doc.text")
                            .font(.caption)
                    }
                    .buttonStyle(.link)
                }
                if !item.isCompleted && !item.reminderDays.isEmpty {
                    Text("알림: " + item.reminderDays.map { $0 == 0 ? "당일" : "\($0)일 전" }.joined(separator: " · "))
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Button("수정") { onEdit() }.controlSize(.small)
            Menu {
                Button("수정") { onEdit() }
                Button(item.isCompleted ? "완료 취소" : "완료") { model.toggleScheduleComplete(item) }
                Divider()
                Button("일정 삭제", role: .destructive) { showDelete = true }
            } label: { Image(systemName: "ellipsis") }
                .frame(width: 24)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        .confirmationDialog("이 일정을 삭제할까요? 메모 원문은 삭제되지 않습니다.", isPresented: $showDelete) {
            Button("일정 삭제", role: .destructive) { model.deleteSchedule(item) }
        }
    }
}

struct WorkOSNoteScheduleStrip: View {
    @EnvironmentObject private var model: WorkOSModel
    let note: WorkNote
    @State private var editorItem: WorkScheduleItem?
    private var items: [WorkScheduleItem] {
        model.scheduleItems.filter { $0.noteID == note.id }.sorted {
            $0.dueDay == $1.dueDay ? $0.dueTime < $1.dueTime : $0.dueDay < $1.dueDay
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("연결된 마감 · 리마인드", systemImage: "calendar.badge.clock")
                    .font(.caption.bold())
                Spacer()
                Button("일정 추가") {
                    editorItem = WorkScheduleItem.make(noteID: note.id,
                        title: note.title.isEmpty ? "후속 업무" : note.title)
                }.controlSize(.small)
            }
            if items.isEmpty {
                Text("이 메모에 연결된 일정이 없습니다. 작성일과 별개로 마감일을 등록할 수 있습니다.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            ForEach(items.prefix(5)) { item in
                HStack(spacing: 8) {
                    Button { model.toggleScheduleComplete(item) } label: {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    }.buttonStyle(.borderless)
                    Text(item.title).font(.caption).lineLimit(1)
                    Spacer()
                    Text(item.dDay).font(.caption2.monospacedDigit())
                        .foregroundStyle(item.isOverdue() ? Color.orange : Color.secondary)
                    Button("수정") { editorItem = item }.font(.caption2).buttonStyle(.link)
                }
            }
            if items.count > 5 {
                Button("연결된 일정 전체 보기") { model.selectedPage = .planner }.font(.caption2)
            }
        }
        .sheet(item: $editorItem) { item in
            WorkOSScheduleEditorSheet(initial: item) { changed in
                model.saveSchedule(changed)
            }
        }
    }
}

struct WorkOSScheduleEditorSheet: View {
    @EnvironmentObject private var model: WorkOSModel
    @Environment(\.dismiss) private var dismiss
    let initial: WorkScheduleItem
    let onSave: (WorkScheduleItem) -> Bool

    @State private var title: String
    @State private var details: String
    @State private var deadlineDay: Date
    @State private var isTimed: Bool
    @State private var deadlineClock: Date
    @State private var reminderClock: Date
    @State private var reminderDays: Set<Int>
    @State private var oneHourBefore: Bool
    @State private var noteID: String
    @State private var noteQuery = ""

    init(initial: WorkScheduleItem, onSave: @escaping (WorkScheduleItem) -> Bool) {
        self.initial = initial
        self.onSave = onSave
        _title = State(initialValue: initial.title)
        _details = State(initialValue: initial.details)
        _deadlineDay = State(initialValue: ScheduleDates.parseDay(initial.dueDay) ?? Date())
        _isTimed = State(initialValue: !initial.dueTime.isEmpty)
        _deadlineClock = State(initialValue: ScheduleDates.date(day: initial.dueDay, time: initial.dueTime) ?? Date())
        _reminderClock = State(initialValue: ScheduleDates.date(day: WorkOSDate.day(), time: initial.reminderTime) ?? Date())
        _reminderDays = State(initialValue: Set(initial.reminderDays))
        _oneHourBefore = State(initialValue: initial.oneHourBefore)
        _noteID = State(initialValue: initial.noteID)
    }

    private var noteMatches: [WorkNote] {
        let trimmed = noteQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matching = model.activeNotes.filter {
            trimmed.isEmpty || $0.visibleTitle.lowercased().contains(trimmed)
        }.sorted { $0.updatedAt > $1.updatedAt }
        var result = Array(matching.prefix(45))
        if let picked = model.activeNotes.first(where: { $0.id == noteID }),
            !result.contains(where: { $0.id == picked.id }) { result.append(picked) }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Label("MemoWeaver 일정 · D-Day", systemImage: "calendar.badge.clock")
                    .font(.title3.bold())
                Spacer()
                Button("취소") { dismiss() }
                Button("저장") { commit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("일정 제목").font(.caption.bold())
                        TextField("예: 계약서 검토 마감, 보고서 제출, 후속 확인", text: $title)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("추가 설명 (선택)").font(.caption.bold())
                        TextEditor(text: $details)
                            .frame(height: 66)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
                    }
                    HStack {
                        DatePicker("마감 날짜", selection: $deadlineDay, displayedComponents: .date)
                            .datePickerStyle(.field)
                        Toggle("시간 지정", isOn: $isTimed)
                    }
                    if isTimed {
                        DatePicker("마감 시각", selection: $deadlineClock, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.field)
                    }
                    Divider()
                    Text("단계별 리마인드").font(.headline)
                    Text("선택한 시점에 Mac의 로컬 알림을 예약합니다. 알림 권한이 없어도 일정은 저장됩니다.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 16) {
                        ForEach([14,7,3,1,0], id: \.self) { lead in
                            Toggle(lead == 0 ? "당일" : "\(lead)일 전", isOn: Binding(
                                get: { reminderDays.contains(lead) },
                                set: { on in
                                    if on { reminderDays.insert(lead) }
                                    else { reminderDays.remove(lead) }
                                }
                            )).toggleStyle(.checkbox)
                        }
                    }
                    DatePicker("사전 알림 시각", selection: $reminderClock, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.field)
                    if isTimed {
                        Toggle("마감 1시간 전에도 알림", isOn: $oneHourBefore)
                        Text("당일 알림은 마감 시각에, 며칠 전 알림은 위에서 정한 시각에 전송됩니다.")
                            .font(.caption2).foregroundStyle(.secondary)
                    } else {
                        Text("시간을 지정하지 않은 일정은 당일 알림도 선택한 사전 알림 시각에 표시됩니다.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Divider()
                    Text("연결할 메모 (선택)").font(.headline)
                    TextField("메모 제목 찾기", text: $noteQuery)
                        .textFieldStyle(.roundedBorder)
                    Picker("참고 메모", selection: $noteID) {
                        Text("메모에 연결하지 않음").tag("")
                        ForEach(noteMatches) { note in
                            Text(note.visibleTitle).tag(note.id)
                        }
                    }
                    .labelsHidden()
                    Text("메모를 연결하면 D-Day에서 해당 기록을 바로 열 수 있습니다. 한 메모에 일정 여러 개를 연결할 수도 있습니다.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.vertical, 5)
            }
        }
        .padding(23)
        .frame(width: 650, height: 700)
    }

    private func commit() {
        var item = initial
        item.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        item.details = details
        item.dueDay = WorkOSDate.day(deadlineDay)
        item.dueTime = isTimed ? ScheduleDates.formatTime(deadlineClock) : ""
        item.reminderTime = ScheduleDates.formatTime(reminderClock)
        item.reminderDays = reminderDays.sorted(by: >)
        item.oneHourBefore = isTimed && oneHourBefore
        item.noteID = noteID
        item.normalize()
        if onSave(item) { dismiss() }
    }
}
