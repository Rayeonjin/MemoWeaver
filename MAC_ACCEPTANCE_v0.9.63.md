# MemoWeaver v0.9.63 / Build 96 - native Mac acceptance checklist

This is a MANUAL test plan, not a record of successful Mac GUI execution.
Use a temporary macOS account or an isolated test database for any restore
experiment. Never perform a destructive restore on your real daily notes.

## A. Build and original data preservation (P0)

1. Quit the installed app. Run `./backup-before-real-use.sh` and store the
   verified archive separately before any installation.
2. Run `./install-v0.9.63.sh --verify` on macOS 14+ with Apple CLT. It must
   complete all tests and a FULL native SwiftUI/AppKit compile, without
   overwriting the installed app or original SQLite.
3. Use a disposable Mac account for the remaining tests, or verify the app
   in a separate isolated environment before upgrading a live account.

## B. Planner create/edit/link/complete (P0)

1. Open the calendar/D-Day planner. Create one standalone all-day deadline
   tomorrow. Confirm correct date, day count and calendar dot/list row.
2. Create a timed deadline and connect it to a disposable note. Verify the
   note strip shows the deadline, the planner shows the linked note, and the
   link opens the correct note without losing the editor caret.
3. Add a SECOND deadline to the same note. Reopen the app and verify both
   deadlines retain their IDs, dates, titles, detail text and note link.
4. Edit the deadline date and time. Check day/list sort, D-Day rollover,
   due-soon/overdue filters, and selected-date navigation.
5. Mark complete then undo completion. Completed tasks must disappear from
   upcoming/overdue and appear in completed; reactivated tasks must return.
6. Delete only one deadline; the linked note and other deadline must survive.
7. Change macOS light/dark appearance and window width; calendar cells,
   descriptions, buttons and confirmation dialogs must not clip or overlap.

## C. Notification center and lifecycle (P0, macOS-only)

1. On the isolated account, explicitly grant MemoWeaver notification permission
   via the planner/settings. Confirm the status label updates.
2. With notification-title privacy OFF (the default), create a timed deadline
   2-3 minutes into the future and enable only the same-day reminder. Keep
   the Mac awake and allow normal notifications. Expect one local notification
   without sensitive task details. Test again with privacy ON and a different
   disposable title.
3. Click a notification for a linked deadline: the app should activate and
   navigate to the linked note. Click a standalone reminder: it should open
   the correct day in the planner.
4. Change a future reminder's deadline to a later minute. Verify the obsolete
   notification does not appear at the original time.
5. Schedule an additional notification, then mark the item complete or delete
   it before its firing time. Verify it does not deliver. Undo completion and
   verify a future reminder can be scheduled again.
6. Quit and reopen the app; verify saved deadlines are still present and
   authorized future notifications can be scheduled. Check with Focus mode
   and notification permission denied; schedules must still save even without
   alert delivery.
7. Run repeated create/edit/complete quickly and check for duplicate or
   stale notifications. **Not verified by source-only tests.**

## D. JSON full restore (P0, isolated Mac account only)

1. With two linked deadlines, export a new `memoweaver-notes` JSON backup.
2. Make a NEW disposable deadline, choose whole restore, and inspect the
   confirmation warning: it must show the current and incoming deadline counts.
3. Restore the new backup. Check the extra deadline disappears and the two
   exported items reappear, with their linked note, title, reminder settings,
   completion state and local alarm registration intact.
4. Repeat with a separately prepared valid legacy `workos-notes` backup.
5. For a malformed deadline backup, expect whole restore to be rejected and
   all previously stored notes/deadlines unchanged.
6. A legacy backup without a `scheduleItems` key intentionally restores ZERO
   deadlines; the confirmation dialog must warn about the count difference.
   Never run this step against real data.

## E. Inherited v0.9.62 regression (P0)

Follow `MAC_ACCEPTANCE_v0.9.62.md` for the slash mouse palette and readable
99-symbol math picker, Korean IME, Undo, tooltip clicks, panes, TSV/image paste,
Mermaid/Markmap/KaTeX and backup/multi-notebook paths.

**Release gate:** The executable is a QA candidate until all applicable Mac
P0 checks pass. Even then, public binary distribution additionally needs the
complete third-party license inventory, an app-source license decision and a
Developer ID/notarization policy.
