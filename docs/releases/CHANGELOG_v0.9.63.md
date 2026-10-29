# MemoWeaver v0.9.63 / Build 96 - Schedule and pre-release QA

Date: 2026-10-28. Baseline: v0.9.62 / Build 95.

## Correctness and safety

- Fixed whole-database restore UI rejecting MemoWeaver's own new-format JSON
  backups: `AppModel.restoreBackupDialog()` now accepts both `memoweaver-notes`
  and `workos-notes` identifiers, matching `Storage.swift`.
- New `MemoWeaverScheduleBackupPreflight.swift`: validates the optional list of
  schedules before destructive restore. Rejects malformed/duplicate schedule
  entries instead of silently losing them when using the tolerant add-only
  importer. Older backups with no schedule field remain supported.
- Whole-restore warning explicitly includes current/incoming schedule counts;
  an older backup can legitimately restore zero schedules. No changes to
  `Storage.swift` or SQLite schema were necessary.

## Tests and packaging

- Added `Tests/ScheduleReleaseV0963Smoke.swift` and `scripts/tests/test-v0.9.63-schedule.sh`,
  plus the original `Tests/PlannerSmoke.swift`. Both use disposable SQLite data.
- Exercised schedule create/update/delete, several deadlines per note, day
  boundaries, leap days, all-day/timed reminders, 1-hour notification,
  the 50-request cap, completion, backup identities and safe replace-all.
- New v0.9.63 wrappers for editor/preview/toolbar tests, installer `--verify`
  runs them alongside the planner regression and performs a full Mac build.
- `build.sh` now packages the existing `THIRD_PARTY_NOTICES.md` into the app.
  This does not complete the transitive license audit. No license was chosen
  for the app itself and no JavaScript bundle was changed.

## Strict boundaries

- Original SQLite schema, note and schedule identity, attachments, AI relations,
  protected source SHA-256s, bundle ID and existing WorkOS data path unchanged.
- macOS full AppKit/SwiftUI build, native notification authorization, actual
  alert delivery, clicking the alert, and GUI UX remain **NOT TESTED** here.
- Public stable release is blocked until these Mac checks and the external
  license/public distribution gates are complete.
