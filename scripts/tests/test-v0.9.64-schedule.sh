#!/bin/bash
# MemoWeaver v0.9.64 schedule and safe-restore verification on disposable SQLite.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
source "$ROOT/tools/qa-swift-env.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/memoweaver-schedule-63.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
SQL_FLAGS=()
if [[ "$(uname -s)" != Darwin ]]; then
  mkdir -p "$TMP/Modules/SQLite3"
  printf 'module SQLite3 [system] { header "/usr/include/sqlite3.h" link "sqlite3" export * }\n' > "$TMP/Modules/SQLite3/module.modulemap"
  SQL_FLAGS=(-I "$TMP/Modules")
fi
"$(command -v swiftc)" -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
FILES=(Models.swift Storage.swift NotebookMembershipCore.swift NotesListFilter.swift
  WorkBlocks.swift QuickCaptureCore.swift MemoryCore.swift MemoryRelationCore.swift
  VirtualMemoryCore.swift MemoWeaverAttachments.swift PlannerCore.swift
  MemoWeaverScheduleBackupPreflight.swift LegacyNoteTextConverter.swift MemoryTimelineCore.swift)
SOURCES=()
for file in "${FILES[@]}"; do SOURCES+=("$ROOT/WorkOSMac/$file"); done
swiftc -swift-version 5 ${SQL_FLAGS[@]+"${SQL_FLAGS[@]}"} -Onone -j 1 -lsqlite3 \
  "${SOURCES[@]}" "$ROOT/Tests/PlannerSmoke.swift" -o "$TMP/planner-existing"
"$TMP/planner-existing"
swiftc -swift-version 5 ${SQL_FLAGS[@]+"${SQL_FLAGS[@]}"} -Onone -j 1 -lsqlite3 \
  "${SOURCES[@]}" "$ROOT/Tests/ScheduleReleaseV0963Smoke.swift" -o "$TMP/planner-release"
"$TMP/planner-release"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import hashlib, plistlib, sys
root=Path(sys.argv[1]);w=root/'WorkOSMac'
app=(w/'AppModel.swift').read_text();storage=(w/'Storage.swift').read_text()
ui=(w/'PlannerViews.swift').read_text();notifs=(w/'ReminderNotifications.swift').read_text()
main=(w/'MainView.swift').read_text();build=(root/'build.sh').read_text()
assert 'MemoWeaverScheduleBackupPreflight.acceptsApp(raw)' in app
assert 'MemoWeaverScheduleBackupPreflight.preservesSchedules(raw)' in app
assert 'replaceAllWithVerifiedBrowserBackup(data)' in app
assert 'incomingScheduleCount' in app
assert 'workos-notes' in storage and 'memoweaver-notes' in storage
for feature in ('model.saveSchedule(changed)', 'model.toggleScheduleComplete(item)', 'model.deleteSchedule(item)', 'model.openSchedule(item.id)', 'requestReminderPermission()', 'ScheduleDates.dayDifference'):
 assert feature in (ui+app), feature
for event in ('getPendingNotificationRequests', 'removePendingNotificationRequests', 'getNotificationSettings', 'UNCalendarNotificationTrigger', 'workosScheduleID', 'generation'):
 assert event in notifs, event
assert 'workosReminderOpened' in main and 'pendingOpenID' in main
assert 'onChange(of: revealNotificationDetails)' in main
assert 'Contents/Resources/THIRD_PARTY_NOTICES.md' in build
assert (root/'THIRD_PARTY_NOTICES.md').exists()
plist=plistlib.loads((w/'Info.plist').read_bytes())
assert (plist['CFBundleShortVersionString'],plist['CFBundleVersion'])==('0.9.64','97')
assert plist['CFBundleIdentifier']=='com.local.workos.notes'
for row in (root/'QA/review-stability-core-source.sha256').read_text().splitlines():
 digest, name=row.split('  ',1)
 assert hashlib.sha256((root/name).read_bytes()).hexdigest()==digest,name + ' changed'
print('PASS v0.9.64 static notification/UI wiring, release checks and reviewed core source hashes')
PY
