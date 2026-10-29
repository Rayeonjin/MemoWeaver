import Foundation

// Review the schedule payload before a destructive whole-database restore.
// The older add-only importer intentionally tolerates imperfect entries, but
// replace-all must never discard unparseable deadlines without warning.
enum MemoWeaverScheduleBackupPreflight {
    static func acceptsApp(_ raw: [String: Any]) -> Bool {
        guard let app = raw["app"] as? String else { return false }
        return app == "memoweaver-notes" || app == "workos-notes"
    }

    static func preservesSchedules(_ raw: [String: Any]) -> Bool {
        guard let payload = raw["scheduleItems"] else { return true } // Legacy backup.
        guard let entries = payload as? [[String: Any]], entries.count <= 60000 else { return false }
        var seen = Set<String>()
        for entry in entries {
            guard let data = try? JSONSerialization.data(withJSONObject: entry),
                  let item = try? JSONDecoder().decode(WorkScheduleItem.self, from: data),
                  !item.id.isEmpty,
                  !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  ScheduleDates.parseDay(item.dueDay) != nil,
                  (item.dueTime.isEmpty || ScheduleDates.hourMinute(item.dueTime) != nil),
                  ScheduleDates.hourMinute(item.reminderTime) != nil,
                  item.reminderDays.allSatisfy({ [0, 1, 3, 7, 14].contains($0) }),
                  seen.insert(item.id).inserted else { return false }
        }
        return true
    }
}

extension LocalDatabase {
    // Call from the restore UI rather than the tolerant add-only import path.
    func replaceAllWithVerifiedBrowserBackup(_ data: Data) throws -> (notes: Int, archives: Int) {
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              MemoWeaverScheduleBackupPreflight.acceptsApp(raw),
              MemoWeaverScheduleBackupPreflight.preservesSchedules(raw) else {
            throw Failure.badBackup
        }
        return try replaceAllWithBrowserBackup(data)
    }
}
