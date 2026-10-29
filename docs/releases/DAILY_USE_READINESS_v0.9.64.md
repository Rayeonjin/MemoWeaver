# MemoWeaver v0.9.64 - daily-note readiness review (excluding the planner)

Date: 2026-10-28. This is a source-level and test-level review, not a native
macOS GUI certification.

## Summary

The current app is functionally useful as a personal, local-first note tool:
fast Markdown source editing, persistent SQLite notes, multi-notebook filing,
full-text/quick search, image/Excel clipboard handling, draft recovery,
local Markdown + KaTeX/Mermaid/Markmap previews, optional local-AI relations,
and backup/import/export. These features are already implemented in the source.

However, a successful Swift parse/SQLite test cannot prove an entire macOS
SwiftUI/AppKit build, Korean IME, runtime pointer selection, scroll focus,
real clipboard payloads or actual backups/restore on a user's Mac. Accordingly,
we recommend a backed-up trial, not a claim of production reliability.

## Actual checks run on current source

- `scripts/tests/test-v0.9.64-pointer-symbols.sh`: 99 unique math symbols, all seven
  categories, unchanged snippet source/caret and slash pointer source contract.
- `scripts/tests/test-v0.9.64-toolkit.sh`, `scripts/tests/test-v0.9.64-live-preview.sh`,
  `scripts/tests/test-v0.9.64-optimization.sh`: insertion, preview engine and optimization.
- `scripts/tests/test-v0.9.60-brand-data.sh`: new/legacy JSON and SQLite compatibility.
- `scripts/tests/test-v0.9.51-notebooks.sh`: multiple notebook links, filtered views,
  migration, restarts and export/import on temporary SQLite.
- `scripts/tests/test-v0.9.60-editor-hotpath.sh`: 12,000-line/200-edit UTF-16 smoke.
- `scripts/tests/test-v0.9.59-ratio-cycle.sh`, `scripts/tests/test-side-preview.sh`: pane ratios and preview.
- `scripts/tests/test-v0.9.27-pinned-paste-ui.sh`: source/layout/clipboard policy;
  AppKit clipboard execution SKIPPED on Linux.
- `scripts/tests/test-v0.9.64-schedule.sh`: planner/backup tests passed unchanged, for regression.
- All eight protected core source hashes match `QA/v0.9.60-core-source.sha256`.

## UI drift corrected in this version

v0.9.61 used seven nested symbol categories but system-menu glyphs were too
small. v0.9.62/63 enlarged the symbols to 25pt but put all 99 in one 455x450
scrolling palette. v0.9.64 restores the original seven-category navigation
at left while keeping legible 25pt glyphs for only the selected category at
right (444x352). Category mouse-hover and click both work by design.
The picker uses neutral hover surfaces matching other toolbar controls.

## Remaining practical gates

1. Native `--verify` full build on macOS 14+; any compiler error blocks release.
2. Create/edit/restart a batch of *realistic test notes* and check saved text,
   backup+restore in an ISOLATED Mac account, Korean IME and Undo.
3. Run v0.9.64 Mac checklist for math popup and slash mouse click, dark/light,
   small windows and popup positioning; real UI is not verified here.
4. Check paste: screenshot image, Finder image drop, Excel TSV/table, plain
   paste and copy-back to TSV.
5. Keep user database folder `~/Library/Application Support/WorkOS/`, bundle ID
   `com.local.workos.notes` and other protected paths unchanged.
6. Public release is a separate decision: incomplete third-party notices,
   absent root project LICENSE and ad-hoc signing remain blocking items.

Planner/notifications can be ignored for note-taking; the feature has NOT been
removed or disabled, and it must not damage ordinary note-taking.
