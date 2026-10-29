import Foundation

@main
struct ScheduleReleaseV0963Smoke {
    static func check(_ condition: Bool, _ message: String) {
        if !condition { fatalError("ScheduleReleaseV0963Smoke: " + message) }
    }

    static func json(_ payload: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    }

    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mw-schedule-63-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let db = try LocalDatabase(directoryOverride: root.appendingPathComponent("live"))
        let note = try db.createNote(typeID: "type-task")
        var deadline = WorkScheduleItem.make(noteID: note.id, title: "Review contract", dueDay: "2028-02-29")
        deadline.details = "One note can have multiple deadlines"
        deadline.dueTime = "08:15"
        deadline.reminderDays = [14, 7, 3, 1, 0, 0]
        deadline.reminderTime = "09:10"
        deadline.oneHourBefore = true
        try db.saveScheduleItem(deadline)
        var second = WorkScheduleItem.make(noteID: note.id, title: "Send response", dueDay: "2028-03-01")
        second.reminderDays = [3, 1, 0]
        try db.saveScheduleItem(second)

        var loaded = try db.scheduledItems()
        check(loaded.count == 2, "two deadlines persisted")
        check(Set(loaded.map(\.noteID)) == [note.id], "one note links to two deadlines")
        check(loaded.first(where: { $0.id == deadline.id })?.reminderDays == [14, 7, 3, 1, 0], "duplicate/invalid reminder days normalized")
        check(loaded.first(where: { $0.id == deadline.id })?.dueTime == "08:15", "timed deadline persisted")
        check(ScheduleDates.parseDay("2028-02-29") != nil, "leap date accepted")
        check(ScheduleDates.parseDay("2027-02-29") == nil, "invalid leap date rejected")
        check(ScheduleDates.hourMinute("24:01") == nil, "invalid time rejected")

        var seoul = Calendar(identifier: .gregorian)
        seoul.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let before = ScheduleDates.date(day: "2028-02-28", time: "23:45", calendar: seoul)!
        check(ScheduleDates.dayDifference(from: before, to: "2028-02-29", calendar: seoul) == 1, "local D-1 near midnight")
        check(ScheduleDates.dayDifference(from: before, to: "2028-02-27", calendar: seoul) == -1, "local D+1 near midnight")
        let moments = ScheduleDates.reminders(for: deadline, after: before, calendar: seoul)
        check(moments.contains(where: { $0.identifier.hasSuffix(".h1") && ScheduleDates.formatTime($0.fireAt, calendar: seoul) == "07:15" }), "one-hour reminder scheduled")
        check(moments.contains(where: { $0.identifier.hasSuffix(".d0") && ScheduleDates.formatTime($0.fireAt, calendar: seoul) == "08:15" }), "timed D-day reminder")
        check(Set(moments.map(\.identifier)).count == moments.count, "unique notification identifiers")
        check(moments.map(\.fireAt) == moments.map(\.fireAt).sorted(), "reminders sorted by actual fire time")
        let allDay = ScheduleDates.reminders(for: second, after: before, calendar: seoul)
        check(allDay.contains(where: { $0.identifier.hasSuffix(".d0") && ScheduleDates.formatTime($0.fireAt, calendar: seoul) == "09:00" }), "all-day reminders use reminder time")

        var timed = loaded.first(where: { $0.id == deadline.id })!
        timed.title = "Review updated contract"
        timed.dueDay = "2028-03-05"
        try db.saveScheduleItem(timed)
        loaded = try db.scheduledItems()
        check(loaded.count == 2, "edit updates in place")
        check(loaded.contains(where: { $0.id == timed.id && $0.title == "Review updated contract" && $0.dueDay == "2028-03-05" }), "edit saved and reloaded")
        timed.markDone(true)
        try db.saveScheduleItem(timed)
        check(ScheduleDates.reminders(for: timed, after: before, calendar: seoul).isEmpty, "completed deadline has no pending reminders")
        timed.markDone(false)
        try db.saveScheduleItem(timed)
        check(!(try db.scheduledItems()).first(where: { $0.id == timed.id })!.isCompleted, "completion can be reversed")

        let many = (0..<40).map { index -> WorkScheduleItem in
            var item = WorkScheduleItem.make(title: "Task \(index)", dueDay: "2029-10-01")
            item.reminderDays = [14, 7, 3, 1, 0]
            return item
        }
        let now = ScheduleDates.date(day: "2029-09-01", time: "12:00")!
        let capped = ScheduleDates.upcomingReminders(many, after: now, limit: 50)
        check(capped.count == 50, "system reminder cap honored")
        check(capped.map(\.fireAt) == capped.map(\.fireAt).sorted(), "nearest reminders first")

        let snapshot = try db.exportBrowserCompatibleJSON()
        var raw = try JSONSerialization.jsonObject(with: snapshot) as! [String: Any]
        check(raw["app"] as? String == "memoweaver-notes", "new backup identity")
        check(MemoWeaverScheduleBackupPreflight.acceptsApp(raw), "new backup identity is accepted")
        check(MemoWeaverScheduleBackupPreflight.preservesSchedules(raw), "valid schedule payload is accepted")
        check((raw["scheduleItems"] as? [[String: Any]])?.count == 2, "backup includes every deadline")

        let restored = try LocalDatabase(directoryOverride: root.appendingPathComponent("restored"))
        _ = try restored.replaceAllWithVerifiedBrowserBackup(snapshot)
        check((try restored.scheduledItems()).count == 2, "new backup restores deadlines")
        check((try restored.notes()).contains(where: { $0.id == note.id }), "new backup restores linked memo")

        raw["app"] = "workos-notes"
        check(MemoWeaverScheduleBackupPreflight.acceptsApp(raw), "old backup identity accepted")
        let older = try LocalDatabase(directoryOverride: root.appendingPathComponent("older"))
        _ = try older.replaceAllWithVerifiedBrowserBackup(json(raw))
        check((try older.scheduledItems()).count == 2, "older backup restores deadlines")

        var invalid = raw
        invalid["scheduleItems"] = [["id": "damaged"]]
        check(!MemoWeaverScheduleBackupPreflight.preservesSchedules(invalid), "incomplete schedule row rejected")
        var rejected = false
        do { _ = try restored.replaceAllWithVerifiedBrowserBackup(json(invalid)) }
        catch { rejected = true }
        check(rejected, "damaged schedule is blocked before destructive restore")
        check((try restored.scheduledItems()).count == 2, "failed restore kept original deadlines")
        check((try restored.notes()).contains(where: { $0.id == note.id }), "failed restore kept original note")

        let rows = raw["scheduleItems"] as! [[String: Any]]
        invalid["scheduleItems"] = [rows[0], rows[0]]
        check(!MemoWeaverScheduleBackupPreflight.preservesSchedules(invalid), "duplicate schedule IDs blocked")
        invalid["scheduleItems"] = "invalid"
        check(!MemoWeaverScheduleBackupPreflight.preservesSchedules(invalid), "invalid schedule payload type blocked")

        var legacy = raw
        legacy.removeValue(forKey: "scheduleItems")
        check(MemoWeaverScheduleBackupPreflight.preservesSchedules(legacy), "legacy backups without schedule fields remain valid")
        let oldWithoutSchedules = try LocalDatabase(directoryOverride: root.appendingPathComponent("legacy"))
        _ = try oldWithoutSchedules.replaceAllWithVerifiedBrowserBackup(json(legacy))
        check((try oldWithoutSchedules.scheduledItems()).isEmpty, "old backup restores zero schedules")
        check((try oldWithoutSchedules.notes()).count == 1, "old backup preserves memo")

        try restored.deleteScheduleItem(second.id)
        check((try restored.scheduledItems()).count == 1, "deleting deadline removes only deadline")
        check(try restored.notes().count == 1, "deleting deadline keeps linked note")
        print("ScheduleReleaseV0963Smoke: PASS (CRUD, multi-deadline, D-Day, local reminders, 50-cap, backup identities, safe restore, old format)")
    }
}
