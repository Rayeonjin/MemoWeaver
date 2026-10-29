import Foundation

@main
struct PlannerSmoke {
    static func expect(_ ok: Bool, _ message: String) {
        if !ok { fatalError("PlannerSmoke: " + message) }
    }

    static func main() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("workos-planner-smoke-" + UUID().uuidString)
        let oldFolder = base.appendingPathComponent("original")
        let restoreFolder = base.appendingPathComponent("restored")
        defer { try? FileManager.default.removeItem(at: base) }

        let db = try LocalDatabase(directoryOverride: oldFolder)
        let note = try db.createNote(typeID: "type-work")
        var item = WorkScheduleItem.make(noteID: note.id, title: "계약 검토 후속 마감", dueDay: "2026-10-28")
        item.reminderDays = [14, 7, 3, 1, 0, 0, 999]
        item.dueTime = "18:00"
        item.oneHourBefore = true
        try db.saveScheduleItem(item)
        let stored = try db.scheduledItems()
        expect(stored.count == 1, "SQLite insert and reload")
        expect(stored[0].noteID == note.id, "note link persisted")
        expect(stored[0].reminderDays == [14, 7, 3, 1, 0], "reminder days normalized")
        expect(stored[0].oneHourBefore, "hour reminder persisted")

        var second = WorkScheduleItem.make(noteID: note.id, title: "진행 사항 중간 점검", dueDay: "2026-10-22")
        second.reminderDays = [1,0]
        try db.saveScheduleItem(second)
        let milestones = try db.scheduledItems()
        expect(milestones.count == 2, "multiple milestones may link to one note")

        // Time zone and day-boundary arithmetic must use calendar days, not 24-hour intervals.
        var korea = Calendar(identifier: .gregorian)
        korea.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let now = ScheduleDates.date(day: "2026-10-19", time: "23:30", calendar: korea)!
        expect(ScheduleDates.dayDifference(from: now, to: "2026-10-20", calendar: korea) == 1,
               "D-1 near midnight")
        expect(ScheduleDates.dayDifference(from: now, to: "2026-10-18", calendar: korea) == -1,
               "overdue day")
        let upcoming = ScheduleDates.reminders(for: item, after: now, calendar: korea)
        expect(upcoming.count == 5, "four future day reminders plus hour before")
        expect(upcoming.contains(where: { $0.identifier.hasSuffix(".h1") }), "1h reminder")
        expect(upcoming.contains(where: { $0.identifier.hasSuffix(".d0") }), "deadline reminder")
        expect(upcoming.map(\.fireAt) == upcoming.map(\.fireAt).sorted(), "chronological reminders")
        expect(Set(upcoming.map(\.identifier)).count == upcoming.count, "unique identifiers")

        var final = stored[0]
        final.markDone(true)
        try db.saveScheduleItem(final)
        let completedRows = try db.scheduledItems()
        expect(completedRows.first(where: { $0.id == final.id })?.isCompleted == true, "completion persisted")
        expect(ScheduleDates.reminders(for: final, after: now, calendar: korea).isEmpty, "completed reminders cancel")

        let backup = try db.exportBrowserCompatibleJSON()
        let snapshot = try JSONSerialization.jsonObject(with: backup) as! [String: Any]
        expect((snapshot["scheduleItems"] as? [[String: Any]])?.count == 2, "JSON backup has deadlines")
        expect((snapshot["notes"] as? [[String: Any]])?.count == 1, "JSON backup still contains notes")
        let restored = try LocalDatabase(directoryOverride: restoreFolder)
        _ = try restored.importBrowserBackup(backup)
        let restoredInitial = try restored.scheduledItems()
        expect(restoredInitial.count == 2, "deadline backup restore")
        let restoredNotes = try restored.notes()
        expect(restoredNotes.count == 1, "linked notes backup restore")
        _ = try restored.importBrowserBackup(backup)
        let restoredAgain = try restored.scheduledItems()
        expect(restoredAgain.count == 2, "import is add-only/idempotent")
        let restoredNotesAgain = try restored.notes()
        expect(restoredNotesAgain.count == 1, "notes remain unique")
        try restored.deleteScheduleItem(second.id)
        let remaining = try restored.scheduledItems()
        expect(remaining.count == 1, "delete only selected deadline")
        let retainedNotes = try restored.notes()
        expect(retainedNotes.count == 1, "deleting deadline does not delete the memo")
        expect(ScheduleDates.parseDay("2026-02-30") == nil, "invalid date rejected")
        expect(ScheduleDates.hourMinute("25:00") == nil, "invalid time rejected")
        print("PlannerSmoke: PASS (SQLite/notes/backup/D-day/reminders/completion/reimport)")
    }
}
