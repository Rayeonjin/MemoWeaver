# MemoWeaver v0.9.61 — start using your real notes

**Goal:** stop extending isolated test versions and establish a safe baseline for daily use. The `WorkOS` storage folder is an intentional compatibility detail, not a second product. Do not rename it or modify `WorkOS.sqlite` with Finder or an external editor.

## One-time setup (Mac)

1. **Quit MemoWeaver** (and any previous WorkOS/기억의 집 app). Confirm no MemoWeaver process is still writing to SQLite.
2. In the unzipped v0.9.61 directory run `./backup-before-real-use.sh`. It archives the entire `~/Library/Application Support/WorkOS/` data directory under `~/Documents/MemoWeaver Backups/`, checks that the tar file can be read, and never changes your database. Copy the archive to an external drive or separate cloud backup location. The archive may contain private text; protect it.
3. Run `./install-v0.9.61.sh --verify` to run suite + **full Mac build without installing**.
4. Only after a successful build, run `./install-v0.9.61.sh`. The installer replaces the app, not the user database, with a rollback procedure for app replacement errors.
5. Open **existing** notes before importing more: sample plain text, Korean characters, attachments, image pastes, spreadsheet tables, mathematical notes, Mermaid and mindmap. Confirm old note counts, notebooks, tags/types, virtual memory search/AI map, and key search results.
6. Begin migration in **small batches** and review them the same day. Paste remaining Markdown directly (or use existing supported backup import paths when appropriate); retired legacy TXT/virtual indexing management screens are intentionally absent. Never overwrite or delete old source files until data appears correctly after a full app restart and another independent backup.
7. Once actual notes are in use, make periodic *app-closed* full data folder archives as well as the app's JSON exports. JSON backups may omit rebuildable caches; the full archive preserves SQLite and attachments.

## Fast acceptance: five operations (~one real workflow)

- Write rapidly in a Korean paragraph, use undo/redo, then switch notes and reopen — text and cursor input must stay responsive.
- Insert a **code block**, choose a language template, edit code, see escaped preview and label; typing source must never execute.
- Insert `$$` math and a Mermaid/Markmap block. Both should refresh without clicking outside their blocks. Context helper menu should appear immediately after insertion.
- Open table-grid icon and verify its popover is attached to that icon; mouse-over tooltip must not clip Korean glyphs, and first click should activate the control.
- Open several notes across notebooks, move divider/preview panels, close/reopen app, confirm selected notes and backup data remain.

## Stop conditions

Do **not** migrate hundreds of notes until fixed if: `--verify` or first build fails, native app crashes opening a note, undo destroys text, note body or attachment is lost after restart, virtual memories disappear, or previously saved notes unexpectedly rewrite on merely opening them. Keep the last working installed version and backup archive; share the first macOS compiler `error:` or a reproducible GUI step.

## Boundaries

- macOS AppKit/SwiftUI whole-app compilation, tooltip appearance, code/context menu placement and benchmark of typing under real workload are not reproducible in the Linux test environment. A passing Swift Foundation test is not equivalent to macOS GUI acceptance.
- The new advanced syntax does not change storage schema. Uncommon Markdown extensions are intentionally not guaranteed to render identically in third-party readers.
