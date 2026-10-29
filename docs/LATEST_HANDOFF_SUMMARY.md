# MemoWeaver / latest developer handoff

**Frozen source baseline:** v0.9.64 / Build 97 (2026-10-28). First GitHub
source-control handoff: 2026-10-29. This repository's application source and
existing tests were copied byte-for-byte from the original full source ZIP.
The new repository policy and Codex documentation do not constitute app code
changes and do not increment the app version.

## What this product is

A native, local-first Mac note app with natural Markdown authoring and optional
AI relationships between saved knowledge fragments. It is NOT primarily a
Markdown document IDE or calendar app. Smooth writing and durable data always
outweigh adding new visible tools.

## Implemented features

- Native four-zone editing workspace with stable split panes / native toolbar.
- Text editing, autosave and recovery, folders/notebooks including multi-notebook
  membership, note kinds, search and virtual memory relationships.
- Optional local Ollama Q&A and similarity analysis; manual/AI links separated.
- Local Markdown preview, KaTeX, Mermaid, Markmap, charts and code fences.
- Native image paste/drop, Markdown tables/Excel TSV conversions, JSON backup.
- Schedule/reminders incl. per-note multiple deadlines, done state, D-day,
  notification time rules; Mac notification behavior still needs real QA.
- Slash commands using keyboard/mouse; category-based math symbol chooser.

## Recent release history (highest version supersedes earlier decisions)

- 0.9.61 Build 94: insertion catalog (21 code languages and advanced Markdown),
  passive tooltip sizing, offline renderer, safe backup workflow.
- 0.9.62 Build 95: slash palette mouse route and 25pt math symbol chooser;
  initial GitHub licensing assessment.
- 0.9.63 Build 96: schedule regression tests, JSON restore preflight fix for
  `memoweaver-notes`, extra validation on planner import; no schema change.
- 0.9.64 Build 97: retained math symbol readability but restored category-first
  navigation and reduced popover size. Planner/persistence/AI unchanged.

## P0 data and GUI constraints

- Keep `com.local.workos.notes` and WorkOS app support storage path.
- Preserve existing SQLite tables and note IDs, multi-notebook joins, original
  Markdown, images/attachments, JSON compatibility, AI/virtual links.
- No dangerous blanket migrations, destructive tests against real data,
  or external network requirements in the default editor.
- Preserve `NSTextView`, native `NSSplitView`, first-click passive tooltip,
  editor caret and IME state; no dynamic tracking separator items.
- Keep one-line 30pt insertion toolbar and 7-category 99-symbol system.

## Quality / limitations

Linux source/runtime test suites were previously reported PASS. Mac SwiftUI/
AppKit whole-app compile, real first-click, notification/GUI, and real
write-save-restart/restore QA are **not verified in this environment**.
`./install-v0.9.64.sh --verify` is the home Mac acceptance gate and DOES NOT
install or overwrite the existing app.

Before source publication: verify copyright holder identity, Apache 2.0 license
adoption, `NOTICE`/brand policy, no sensitive files, and full licensing of the
5.6MB JS bundle. The latter is an **open compliance gap**, not a sign-off.

## Next weekly session

1. From the home Mac: inspect `git status`, baseline source, and selected issue.
2. Make only one limited, testable update; regression-test it.
3. Confirm normal notes workflow, not just unit tests, with temporary data.
4. Produce changelog + real Mac acceptance notes, new release number/build,
   and update this handoff before merge/tag/push.
5. Read `docs/WEEKLY_CODEX_PLAYBOOK.md`; stay out of user's live DB.

The private transfer archive also contains the full 155K historical Korean
handoff and the exact original v0.9.64 source ZIP. Neither belongs in public Git.
