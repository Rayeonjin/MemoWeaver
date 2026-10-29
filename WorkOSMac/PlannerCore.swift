import Foundation

// A scheduled action is independent of noteDate (the date a note was written).
// Several scheduled actions may point to the same note, and standalone actions are allowed.
struct WorkScheduleItem: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var details: String
    var dueDay: String                 // Local calendar YYYY-MM-DD; not UTC.
    var dueTime: String                // Empty = all-day; otherwise HH:mm.
    var noteID: String                 // Empty = standalone.
    var completedAt: String
    var createdAt: String
    var updatedAt: String
    var reminderDays: [Int]            // Days before due, e.g. [7,3,1,0].
    var reminderTime: String           // Local HH:mm on earlier/all-day reminder days.
    var oneHourBefore: Bool            // Only for timed deadlines.

    static func make(noteID: String = "", title: String = "", dueDay: String = WorkOSDate.day()) -> Self {
        let timestamp = WorkOSDate.now()
        return WorkScheduleItem(id: UUID().uuidString, title: title, details: "", dueDay: dueDay,
            dueTime: "", noteID: noteID, completedAt: "", createdAt: timestamp, updatedAt: timestamp,
            reminderDays: [3, 1, 0], reminderTime: "09:00", oneHourBefore: false)
    }

    var isCompleted: Bool { !completedAt.isEmpty }
    var isAllDay: Bool { dueTime.isEmpty }
    var dDay: String {
        let delta = ScheduleDates.dayDifference(from: Date(), to: dueDay)
        if delta == 0 { return "D-Day" }
        return delta > 0 ? "D-\(delta)" : "D+\(-delta)"
    }
    func isOverdue(now: Date = Date()) -> Bool {
        guard !isCompleted else { return false }
        let delta = ScheduleDates.dayDifference(from: now, to: dueDay)
        if delta < 0 { return true }
        if delta > 0 { return false }
        guard !dueTime.isEmpty, let due = ScheduleDates.date(day: dueDay, time: dueTime) else { return false }
        return due < now
    }
    func isDueToday(now: Date = Date()) -> Bool {
        !isCompleted && ScheduleDates.dayDifference(from: now, to: dueDay) == 0
    }
    mutating func markDone(_ completed: Bool) {
        completedAt = completed ? WorkOSDate.now() : ""
    }
    mutating func normalize() {
        reminderDays = Array(Set(reminderDays.filter { [14,7,3,1,0].contains($0) })).sorted(by: >)
        if ScheduleDates.hourMinute(reminderTime) == nil { reminderTime = "09:00" }
        if ScheduleDates.hourMinute(dueTime) == nil { dueTime = ""; oneHourBefore = false }
    }
}

struct ScheduleReminderMoment: Hashable {
    let identifier: String
    let scheduleID: String
    let fireAt: Date
    let heading: String
    let message: String
}

enum ScheduleDates {
    static func parseDay(_ text: String, calendar: Calendar = .current) -> Date? {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1900...2200).contains(year), (1...12).contains(month), (1...31).contains(day),
              let parsed = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) else { return nil }
        let check = calendar.dateComponents([.year,.month,.day], from: parsed)
        guard check.year == year && check.month == month && check.day == day else { return nil }
        return parsed
    }
    static func hourMinute(_ text: String) -> (Int, Int)? {
        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].count == 2, parts[1].count == 2,
              let h = Int(parts[0]), let m = Int(parts[1]), (0...23).contains(h), (0...59).contains(m) else { return nil }
        return (h,m)
    }
    static func date(day: String, time: String, calendar: Calendar = .current) -> Date? {
        guard let base = parseDay(day, calendar: calendar), let (hour,minute) = hourMinute(time) else { return nil }
        let ymd = calendar.dateComponents([.year,.month,.day], from: base)
        return calendar.date(from: DateComponents(year: ymd.year, month: ymd.month, day: ymd.day,
                hour: hour, minute: minute))
    }
    static func dayDifference(from now: Date, to targetDay: String, calendar: Calendar = .current) -> Int {
        guard let target = parseDay(targetDay, calendar: calendar) else { return 0 }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: target)).day ?? 0
    }
    static func dayString(_ date: Date, calendar: Calendar = .current) -> String {
        let comp = calendar.dateComponents([.year,.month,.day], from: date)
        return String(format: "%04d-%02d-%02d", comp.year ?? 0, comp.month ?? 0, comp.day ?? 0)
    }
    static func formatTime(_ date: Date, calendar: Calendar = .current) -> String {
        let comp = calendar.dateComponents([.hour,.minute], from: date)
        return String(format: "%02d:%02d", comp.hour ?? 9, comp.minute ?? 0)
    }
    static func reminders(for item: WorkScheduleItem, after now: Date = Date(), calendar: Calendar = .current) -> [ScheduleReminderMoment] {
        guard !item.isCompleted, !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let dueDay = parseDay(item.dueDay, calendar: calendar) else { return [] }
        let earlierTime = hourMinute(item.reminderTime) ?? (9, 0)
        var output: [ScheduleReminderMoment] = []
        for lead in Set(item.reminderDays).filter({ [0,1,3,7,14].contains($0) }).sorted(by: >) {
            guard let shifted = calendar.date(byAdding: .day, value: -lead, to: dueDay) else { continue }
            let onDay = dayString(shifted, calendar: calendar)
            let time = (lead == 0 && !item.dueTime.isEmpty) ? item.dueTime :
                String(format: "%02d:%02d", earlierTime.0, earlierTime.1)
            guard let fire = date(day: onDay, time: time, calendar: calendar), fire > now else { continue }
            let label = lead == 0 ? "D-Day" : "D-\(lead)"
            output.append(ScheduleReminderMoment(identifier: "workos.schedule.\(item.id).d\(lead)",
                scheduleID: item.id, fireAt: fire, heading: "\(label) · \(item.title)",
                message: "마감일 \(item.dueDay)\(item.dueTime.isEmpty ? "" : " \(item.dueTime)") · MemoWeaver 일정"))
        }
        if item.oneHourBefore, !item.dueTime.isEmpty,
           let due = date(day: item.dueDay, time: item.dueTime, calendar: calendar) {
            let fire = due.addingTimeInterval(-3600)
            if fire > now {
                output.append(ScheduleReminderMoment(identifier: "workos.schedule.\(item.id).h1",
                    scheduleID: item.id, fireAt: fire, heading: "1시간 전 · \(item.title)",
                    message: "\(item.dueDay) \(item.dueTime) 마감 예정"))
            }
        }
        return output.sorted { $0.fireAt < $1.fireAt }
    }
    // OS pending local notifications are limited; preserve the nearest dates first.
    static func upcomingReminders(_ items: [WorkScheduleItem], after now: Date = Date(), limit: Int = 50) -> [ScheduleReminderMoment] {
        Array(items.flatMap { reminders(for: $0, after: now) }
            .sorted { $0.fireAt < $1.fireAt }.prefix(limit))
    }
}
